import Foundation

/// Строка в списке чатов — в меню и в истории.
struct ChatSummary: Identifiable, Equatable {
    let id: String
    let title: String
}
