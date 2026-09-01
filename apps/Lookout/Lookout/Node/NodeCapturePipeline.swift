import AVFoundation
import CoreImage
import UIKit

enum CaptureError: Error {
    case cameraUnavailable
    case notAuthorized
}

/// JPEG frames at ~10 fps for a first-run live feed that does not need SPS/PPS.
final class NodeCapturePipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onJPEG: ((Data) -> Void)?
    private(set) var latestJPEG: Data?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "lookout.capture")
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private var lastEmit = CFAbsoluteTimeGetCurrent()
    private let minInterval: CFAbsoluteTime = 0.1

    func start() throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            // Caller should request access first.
        } else if status != .authorized {
            throw CaptureError.notAuthorized
        }

        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            throw CaptureError.cameraUnavailable
        }
        session.addInput(input)

        try? device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 10)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 10)
        device.unlockForConfiguration()

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CaptureError.cameraUnavailable
        }
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        session.commitConfiguration()
        queue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastEmit >= minInterval else { return }
        lastEmit = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let data = context.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else {
            return
        }
        latestJPEG = data
        onJPEG?(data)
    }
}
