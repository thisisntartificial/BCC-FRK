import Foundation

/// Converts the amplification the user asks for into what the audio graph
/// wants.
///
/// Users think in multiples ("make it four times louder"); the gain stage is
/// configured in decibels and refuses anything past its ceiling. Getting this
/// conversion wrong is quiet rather than loud — the slider simply stops having
/// an effect — so it is worth testing directly.
public enum GainStage {
    /// `AVAudioUnitEQ.globalGain` accepts at most +24 dB.
    public static let maximumDB: Float = 24

    /// Multiples the gain stage can actually deliver. The upper bound is
    /// `maximumDB` expressed as a multiple, rounded down so the slider never
    /// promises amplification the hardware will silently drop.
    public static let supportedRange: ClosedRange<Float> = 1 ... 15

    public static func decibels(forMultiplier multiplier: Float) -> Float {
        guard multiplier.isFinite, multiplier > 0 else { return 0 }

        let clamped = min(
            max(multiplier, supportedRange.lowerBound),
            supportedRange.upperBound
        )
        return min(20 * log10(clamped), maximumDB)
    }
}
