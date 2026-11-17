import SwiftUI


extension View {
    /// The one-off explainer shown the first time Transcribe is tapped. Put
    /// on the root and on each sheet that has a Transcribe key, so it shows
    /// on top of whatever is open.
    /// `enabled` false while something covers this screen (e.g. the full
    /// player), so the alert shows on the top one only.
    func transcribeExplainer(enabled: Bool = true) -> some View {
        modifier(TranscribeExplainer(enabled: enabled))
    }
}

private struct TranscribeExplainer: ViewModifier {
    @Environment(TranscriptService.self) private var transcripts
    var enabled = true

    func body(content: Content) -> some View {
        content.alert("Transcribe on this iPhone?", isPresented: Binding(get: { enabled && transcripts.explainEpisode != nil }, set: { _ in })) {
            // Listed in this order, Transcribe shows on the left.
            Button("Transcribe") { transcripts.confirmExplainer() }
            Button("Not now") { transcripts.explainEpisode = nil }
        } message: {
            Text(message)
        }
    }

    private var message: String {
        let time = transcripts.typicalMinutesPerHour.map { "About \(max(1, Int($0.rounded()))) min per hour of audio." }
            ?? "A few minutes per hour of audio."
        return "Made from the download; nothing leaves your phone.\n\(time)\nUses battery while it runs. Stop it any time."
    }
}
