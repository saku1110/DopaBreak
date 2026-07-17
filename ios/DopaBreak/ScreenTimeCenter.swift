import FamilyControls
import Observation

@MainActor
@Observable
final class ScreenTimeCenter {
    private(set) var isAuthorized: Bool = false

    func refresh() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
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
