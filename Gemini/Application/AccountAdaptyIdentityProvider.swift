import BroadMonetization

/// Отдаёт Adapty тот же account ID, что уже видит бэкенд и что показан
/// в Settings как «Account ID». Это не произвольный выбор: тестеру нужно
/// зачислять токены/подписку по одному и тому же ID что в Adapty, что на бэке.
struct AccountAdaptyIdentityProvider: AdaptyIdentityProviderProtocol {
    private let accountRepository: any AccountRepositoryProtocol

    init(accountRepository: any AccountRepositoryProtocol) {
        self.accountRepository = accountRepository
    }

    func identity(for subject: EntitlementSubject) async -> AdaptyCustomerIdentity? {
        guard let accountID = try? await accountRepository.loadAccountID() else {
            return nil
        }
        return AdaptyCustomerIdentity(subject: subject, customerUserID: accountID)
    }
}
