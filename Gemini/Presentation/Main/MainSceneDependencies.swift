/// Зависимости основной сцены — только use case'ы домена.
///
/// Экран не знает ни про сеть, ни про заглушки: он получает готовые сценарии.
///
/// **Это не значит, что подключение backend — «замена четырёх строк».** Слой
/// разделён правильно, и вёрстка переживёт подключение почти без правок, но сами
/// контракты писались до спецификации API: реальная генерация трёхшаговая
/// (создать разговор → получить job → опрашивать до готовности), история курсорная,
/// а монетизация вообще не прячется за этими протоколами — её приносит платформа
/// со своим `PaywallViewModel` и `EntitlementEngine`.
///
/// Что именно придётся дописать — в `docs/specs/2026-08-20-gemini-design.md`.
@MainActor
struct MainSceneDependencies {
    let sendMessage: SendMessageUseCase
    let generateMedia: GenerateMediaUseCase
    let loadChats: LoadChatsUseCase
    let loadMessages: LoadMessagesUseCase
    let renameChat: RenameChatUseCase
    let deleteChat: DeleteChatUseCase
    let loadModels: LoadModelsUseCase
    let loadLibrary: LoadLibraryUseCase
    let saveGeneration: SaveGenerationUseCase
    let saveToPhotos: PhotoLibrarySaver
    let deleteGeneration: DeleteGenerationUseCase
    let loadAccount: LoadAccountUseCase
    let rateUsPolicy: RateUsPolicy
    let specialOfferPolicy: SpecialOfferPolicy
    let aiConsentPolicy: AIConsentPolicy
}
