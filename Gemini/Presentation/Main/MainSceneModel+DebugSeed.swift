#if DEBUG
    import CoreGraphics
    import Foundation

    /// Наполнение экранов для проверки без backend.
    ///
    /// Живёт отдельно от самой модели и только в Debug: в релизной сборке этого кода нет.
    ///
    /// ```bash
    /// xcrun simctl launch <device> com.ras.5137g4m769 -route main -seed settings
    /// ```
    extension MainSceneModel {
        func applyDebugSeedIfNeeded() {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-seed"), index + 1 < arguments.count else {
                return
            }

            switch arguments[index + 1] {
            case "chat":
                seedConversation()
            case "tokens":
                seedConversation()
                notice = .tokensExhausted
                balance = .tokenBalance(0)
            case "limit":
                seedConversation()
                notice = .dailyLimitReached
            case "error":
                messages = [
                    ChatMessage(id: "1", author: .user,
                                text: "Give me an idea for a healthy breakfast"),
                    ChatMessage(id: "2", author: .assistant, text: "", status: .failed)
                ]
                chatTitle = "Healthy breakfast idea"
            case "generation-in-chat":
                messages = [
                    ChatMessage(id: "1", author: .user,
                                text: "A lone medieval knight in silver armor lying in a field "
                                    + "of purple wildflowers, dreamy cinematic lighting."),
                    ChatMessage(id: "2", author: .assistant, text: "",
                                generation: LibraryItem(id: "g1", kind: .image, url: nil))
                ]
                chatTitle = "Image generation"
            case "code":
                messages = [
                    ChatMessage(id: "1", author: .user, text: "Show me a Swift snippet"),
                    ChatMessage(id: "2", author: .assistant, text: Self.codeReply)
                ]
                chatTitle = "Swift snippet"
            case "dictation":
                startVoiceInput()
            case "picker-photos":
                attachmentSource = .photos
            case "picker-files":
                attachmentSource = .files
            case "web-search":
                chatMode = .research
                messages = [
                    ChatMessage(id: "1", author: .user,
                                text: "What are the latest findings on protein and satiety?"),
                    ChatMessage(id: "2", author: .assistant,
                                text: "Higher-protein breakfasts increase satiety hormones and "
                                    + "reduce later snacking, according to recent trials.",
                                sources: PreviewData.sources)
                ]
                chatTitle = "Protein and satiety"
            case "menu":
                isMenuOpen = true
            case "menu-paywall":
                // Проверка того, что пейвол открывается поверх меню:
                // с накрытого экрана второе модальное окно не поднималось.
                isMenuOpen = true
                openPaywall(.subscription)
            case "history":
                menuPath = [.history]
            case "library":
                menuPath = [.library]
            case "settings":
                menuPath = [.settings]
                balance = .tokenBalance(500)
            case "model-picker":
                isModelPickerPresented = true
            case "voice":
                voice = VoiceInputState(
                    levels: (0 ..< 44).map { _ in CGFloat.random(in: 0.2 ... 1) },
                    duration: .seconds(12)
                )
            case "transcribing":
                voice = VoiceInputState(
                    levels: (0 ..< 44).map { _ in CGFloat.random(in: 0.2 ... 1) },
                    duration: .seconds(12),
                    isTranscribing: true
                )
            case "composer-files":
                pendingAttachments = [
                    ChatAttachment(id: "1", kind: .document(name: "Meal-Plan.JSX"), isUploading: true),
                    ChatAttachment(id: "2", kind: .document(name: "Hotel Reservation.pdf"))
                ]
            case "attachments":
                sheet = .attachments
            case "tokens-paywall":
                cover = .paywall(.tokens)
            case "special-offer":
                // Ждём каталог: предложение собирается после загрузки плейсментов,
                // а сид срабатывает раньше — без ожидания экран всегда пустой.
                // Через `openPaywall`, а не прямым присваиванием: там взводится
                // таймер, без которого экран открывается уже истёкшим.
                Task { @MainActor in
                    await paywallCatalog.load()
                    openPaywall(.specialOffer)
                }
            case "rate-us":
                cover = .rateUs
            case "update":
                sheet = .appUpdate
            case "current-plan":
                menuPath = [.settings]
                balance = .tokenBalance(500)
                sheet = .currentPlan
            case "rate-popup":
                menuPath = [.settings]
                balance = .tokenBalance(500)
                sheet = .rateUsPrompt
            case "generation-settings":
                selectedModelID = "imagen-3"
                balance = .tokenBalance(500)
                sheet = .generationSettings
            case "image-model":
                selectedModelID = "imagen-3"
                balance = .tokenBalance(500)
            case "banner":
                isGenerationReadyBannerPresented = true
            case "generation":
                cover = .generation(LibraryItem(id: "1", kind: .image, url: nil))
            default:
                break
            }
        }

        /// Ответ с листингом — на нём проверяются блок кода и выделение текста.
        private static let codeReply = """
        Here is a small helper that trims whitespace and drops empty lines.

        Call `normalize(_:)` before sending the prompt:

        ```swift
        func normalize(_ text: String) -> String {
            text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: "\\n")
        }
        ```

        It keeps the prompt readable and saves a few tokens.
        """

        private func seedConversation() {
            messages = PreviewData.conversation
            chatTitle = "Healthy breakfast idea"
        }
    }
#endif
