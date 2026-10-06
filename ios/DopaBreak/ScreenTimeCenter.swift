import FamilyControls
import Observation

@MainActor
@Observable
final class ScreenTimeCenter {
    private let authorizationStatusProvider: () -> AuthorizationStatus
    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    private(set) var isAuthorized: Bool = false

    init(
        authorizationStatusProvider: @escaping () -> AuthorizationStatus = {
            AuthorizationCenter.shared.authorizationStatus
        }
    ) {
        self.authorizationStatusProvider = authorizationStatusProvider
    }

    func refresh() {
        authorizationStatus = authorizationStatusProvider()
        isAuthorized = authorizationStatus == .approved
    }

    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refresh()
            return isAuthorized
        } catch {
            refresh()
            return false
        }
    }
}
