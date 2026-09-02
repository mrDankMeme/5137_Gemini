import Foundation

/// Генерация изображений и видео через раздел `/v1/media`.
///
/// Через переписку это не делается: `POST /v1/chat/v2/run` принимает только
/// чат-модели — на идентификатор fal он отвечает `422 validation_error`, —
/// а попросив словами «сгенерируй картинку», в ответ получаешь её словесное
/// описание и ни одной задачи. Поэтому здесь свой путь: задача заводится
/// в `/v1/media/images` или `/v1/media/videos` и опрашивается до готовности.
///
/// Исходники для «по картинке» уезжают отдельной ручкой и передаются ссылками:
/// файл скачивает сам провайдер, байты в теле задачи он не принимает.
actor NetworkMediaGenerationRepository: MediaGenerationRepositoryProtocol {
    private let client: APIClient
    /// Готовая генерация ложится в локальный архив: серверной переписки у неё
    /// нет, и без архива картинка пропадала из чата при выходе с экрана.
    private let archive: GenerationArchive

    /// Видео генерируется минутами, картинка — секундами, поэтому терпения
    /// у опроса разное. Интервал общий: чаще двух секунд смысла нет.
    private nonisolated static let pollInterval = Duration.seconds(2)
    private nonisolated static let imageAttempts = 90
    private nonisolated static let videoAttempts = 240
    /// Сколько подряд неудачных опросов терпим, прежде чем сдаться.
    private nonisolated static let pollFailureLimit = 5

    init(client: APIClient, archive: GenerationArchive) {
        self.client = client
        self.archive = archive
    }

    func generate(
        prompt: String,
        chatID: ChatSummary.ID?,
        model: AIModel,
        kind: LibraryItem.Kind,
        settings: GenerationSettings,
        referenceImages: [ChatAttachment]
    ) async throws -> SentMessage {
        let urls = try await upload(referenceImages)
        // Ступень качества уходит только в том виде, в каком её называет сама
        // модель, и только если она их принимает: Kling ступеней не знает, а
        // Veo на «1K» отвечает `422 resolution is not supported`.
        let resolution = settings.resolution.wireValue(supportedBy: model.resolutions)
        // Переписку заводим сами, до исхода задачи: сервер о ней не знает
        // и в `/v1/chats` она не появится никогда.
        let conversation = chatID.flatMap { GenerationArchive.isArchived($0) ? $0 : nil }
            ?? GenerationArchive.makeChatID()
        let placeholderID = UUID().uuidString

        do {
            let job: MediaJobDTO = switch kind {
            case .image:
                try await client.post("/v1/media/images", body: ImageRequestDTO(
                    model: model.id,
                    prompt: prompt,
                    imageUrls: urls.isEmpty ? nil : urls,
                    aspectRatio: settings.aspectRatio.wireValue,
                    resolution: resolution
                ))
            case .video:
                try await client.post("/v1/media/videos", body: VideoRequestDTO(
                    model: model.id,
                    prompt: prompt,
                    imageUrl: urls.first,
                    aspectRatio: settings.aspectRatio.wireValue,
                    resolution: resolution,
                    duration: String(settings.duration.wireValue),
                    generateAudio: settings.isSoundOn
                ))
            }

            // Job создан и кредиты уже списаны — переписка обязана быть видна
            // в истории прямо сейчас, лоадером вместо ответа. Без этого уход
            // из чата на генерацию, которая идёт минутами, делал её ненаходимой
            // до самого завершения: чат появлялся в архиве только по успеху,
            // а отменённая на середине опроса задача до этого места не
            // дописывалась вовсе — переписка исчезала без следа.
            await archive.beginPending(
                chatID: conversation,
                title: prompt,
                prompt: prompt,
                placeholderID: placeholderID
            )

            do {
                let item = try await wait(for: job, chatID: conversation, kind: kind, prompt: prompt, model: model)
                let message = ChatMessage(id: item.id, author: .assistant, text: "", generation: item)
                await archive.complete(chatID: conversation, placeholderID: placeholderID, result: message)
                return SentMessage(chatID: conversation, chatTitle: prompt, message: message)
            } catch {
                // Плейсхолдер остаётся в переписке с ошибкой — тот же красный
                // пузырь и кнопка повтора, что у обычного неудавшегося
                // текстового ответа, а не немое исчезновение попытки.
                await archive.fail(chatID: conversation, placeholderID: placeholderID)
                throw error
            }
        } catch let error as APIError {
            throw Self.chatError(for: error, chatID: conversation)
        }
    }

    // MARK: Исходники

    private func upload(_ attachments: [ChatAttachment]) async throws -> [String] {
        var urls: [String] = []
        for attachment in attachments {
            // Референсом может быть только картинка: документ провайдеру
            // нечего показывать, а задача с ним просто упала бы.
            guard let payload = attachment.payload,
                  let mimeType = attachment.mimeType,
                  mimeType.hasPrefix("image/")
            else {
                continue
            }

            let response: UploadResponseDTO = try await client.post(
                "/v1/media/uploads",
                body: UploadRequestDTO(
                    type: "image",
                    mediaType: mimeType,
                    filename: Self.filename(for: attachment, mimeType: mimeType),
                    data: payload.base64EncodedString()
                )
            )
            urls.append(response.url)
        }
        return urls
    }

    /// Имя файла ручка требует обязательно: без него она отвечает 422 и
    /// ломается каждая генерация «по картинке».
    private nonisolated static func filename(for attachment: ChatAttachment, mimeType: String) -> String {
        if case let .document(name) = attachment.kind {
            return name
        }
        let ext = mimeType.split(separator: "/").last.map(String.init) ?? "jpg"
        return "reference-\(attachment.id).\(ext)"
    }

    // MARK: Ожидание результата

    private func wait(
        for job: MediaJobDTO,
        chatID: String,
        kind: LibraryItem.Kind,
        prompt: String,
        model: AIModel
    ) async throws -> LibraryItem {
        var state = job
        var failures = 0
        let attempts = kind == .video ? Self.videoAttempts : Self.imageAttempts

        for _ in 0 ..< attempts {
            switch state.status {
            case "completed", "succeeded", "done":
                guard let url = state.assets.first.flatMap({ URL(string: $0.url) }) else {
                    throw ChatError.generationFailed(chatID: chatID)
                }
                return LibraryItem(
                    id: state.jobId,
                    kind: kind,
                    url: url,
                    prompt: prompt,
                    modelID: model.id
                )
            case "failed", "cancelled":
                throw ChatError.generationFailed(chatID: chatID)
            default:
                break
            }

            try await Task.sleep(for: Self.pollInterval)
            try Task.checkCancellation()
            do {
                state = try await client.get("/v1/media/jobs/\(job.jobId)")
                failures = 0
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Разовый сбой опроса — не провал генерации: задача на сервере
                // жива, кредиты списаны, и картинка будет. Обрывалось это уже
                // живьём: один неудачный запрос показывал «Failed to generate»
                // на генерации, которая через минуту лежала готовой.
                failures += 1
                guard failures < Self.pollFailureLimit else { throw error }
            }
        }

        // Терпение кончилось, а задача — нет: она осталась на сервере и
        // подтянется в библиотеку сама, при следующей её загрузке.
        throw ChatError.generationFailed(chatID: chatID)
    }

    /// Кредиты кончились — это не сбой генерации, а повод показать пейвол
    /// пакетов. Всё остальное для экрана одинаково: генерация не удалась.
    private nonisolated static func chatError(for error: APIError, chatID: String) -> ChatError {
        if case let .server(_, code, _) = error, code == "insufficient_credits" {
            return .outOfTokens(chatID: chatID)
        }
        return .generationFailed(chatID: chatID)
    }
}

// MARK: - Формы запросов и ответов backend

private nonisolated struct ImageRequestDTO: Encodable {
    let model: String
    let prompt: String
    let imageUrls: [String]?
    let aspectRatio: String?
    let resolution: String?
}

private nonisolated struct VideoRequestDTO: Encodable {
    let model: String
    let prompt: String
    let imageUrl: String?
    let aspectRatio: String?
    let resolution: String?
    let duration: String?
    let generateAudio: Bool?
}

private nonisolated struct UploadRequestDTO: Encodable {
    let type: String
    let mediaType: String
    let filename: String
    let data: String
}

private nonisolated struct UploadResponseDTO: Decodable {
    let url: String
}

private nonisolated struct MediaJobDTO: Decodable {
    struct Asset: Decodable {
        let url: String
    }

    let jobId: String
    let status: String
    let assets: [Asset]
}
