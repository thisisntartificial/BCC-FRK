import AVFoundation
import CoreMedia
import VideoToolbox

/// Phase 1 capture + encode on the Camera Node.
/// Preview on the Node is optional; turn it off when thermal state is elevated.
final class NodeCapturePipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onEncoded: ((Data, CMTime) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "lookout.capture")
    private var compressor: VTCompressionSession?
    private let fps: Int32 = 15

    func start() throws {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            throw CaptureError.cameraUnavailable
        }
        session.addInput(input)

        try device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: fps)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: fps)
        device.unlockForConfiguration()

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw CaptureError.cameraUnavailable }
        session.addOutput(output)
        if let connection = output.connection(with: .video) {
            connection.videoRotationAngle = 90
        }
        session.commitConfiguration()

        try createCompressor()
        session.startRunning()
    }

    func stop() {
        session.stopRunning()
        if let compressor {
            VTCompressionSessionInvalidate(compressor)
        }
        compressor = nil
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let compressor, let image = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        VTCompressionSessionEncodeFrame(
            compressor,
            imageBuffer: image,
            presentationTimeStamp: pts,
            duration: .invalid,
            frameProperties: nil,
            infoFlagsOut: nil
        ) { [weak self] _, _, encoded in
            guard let encoded, let data = Self.annexBData(from: encoded) else { return }
            self?.onEncoded?(data, CMSampleBufferGetPresentationTimeStamp(encoded))
        }
    }

    private func createCompressor() throws {
        let width = 1280
        let height = 720
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        guard status == noErr, let session else { throw CaptureError.encodeFailed }

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: fps as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: 1_200_000 as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: fps as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(session)
        compressor = session
    }

    /// Convert AVCC length-prefixed NALs to Annex-B for a simple TCP payload.
    private static func annexBData(from sample: CMSampleBuffer) -> Data? {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sample) else { return nil }
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer) == noErr,
              let dataPointer
        else { return nil }

        var data = Data(bytes: dataPointer, count: length)
        var offset = 0
        while offset + 4 <= data.count {
            let naluLength = Int(data.subdata(in: offset..<offset + 4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            data.replaceSubrange(offset..<offset + 4, with: [0, 0, 0, 1])
            offset += 4 + naluLength
        }
        return data
    }
}

enum CaptureError: Error {
    case cameraUnavailable
    case encodeFailed
}

// MARK: - Viewer display

/// Decode Annex-B on the Viewer and enqueue onto a display layer.
final class ViewerDisplay {
    let layer = AVSampleBufferDisplayLayer()
    private var format: CMVideoFormatDescription?
    private var session: VTDecompressionSession?

    func enqueueAnnexB(_ data: Data, pts: CMTime) {
        // Production code should parse SPS/PPS, build a format description,
        // then wrap each NAL as a CMSampleBuffer. Keep that on a decode queue.
        // See VTDecompressionSessionDecodeFrame and AVSampleBufferDisplayLayer.enqueue.
        _ = data
        _ = pts
        _ = format
        _ = session
    }
}
