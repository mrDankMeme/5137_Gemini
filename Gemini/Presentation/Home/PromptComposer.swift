import SwiftUI

/// Нижний блок ввода: обычное поле или дорожка звука во время диктовки.
///
/// Один компонент на главный экран и на чат — раньше эта развилка была
/// продублирована в обоих экранах.
struct PromptComposer: View {
    @Binding var text: String
    let placeholder: String
    var voice: VoiceInputState?
    var isSending = false
    var isGenerating = false
    /// См. `PromptBar.isReady`.
    var isReady = true

    let onAttach: () -> Void
    let onVoice: () -> Void
    let onSend: () -> Void
    var onStop: () -> Void = {}
    let onCancelVoice: () -> Void
    let onConfirmVoice: () -> Void
    var showsGenerationSettings = false
    var onOpenGenerationSettings: () -> Void = {}
    @Binding var mode: ChatMode
    var attachments: [ChatAttachment] = []
    var onRemoveAttachment: (ChatAttachment) -> Void = { _ in }
    /// См. `PromptBar.isFocused` — фокусом владеет экран.
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        if let voice {
            VoiceRecorderBar(
                levels: voice.levels,
                duration: voice.duration,
                isTranscribing: voice.isTranscribing,
                onCancel: onCancelVoice,
                onConfirm: onConfirmVoice
            )
        } else {
            PromptBar(
                text: $text,
                placeholder: placeholder,
                isSending: isSending,
                isReady: isReady,
                isGenerating: isGenerating,
                onAttach: onAttach,
                onVoice: onVoice,
                onSend: onSend,
                onStop: onStop,
                showsGenerationSettings: showsGenerationSettings,
                onOpenGenerationSettings: onOpenGenerationSettings,
                mode: $mode,
                attachments: attachments,
                onRemoveAttachment: onRemoveAttachment,
                isFocused: $isFocused
            )
        }
    }
}
