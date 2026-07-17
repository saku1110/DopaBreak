import DopaBreakCore
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        do {
            let goalStore = GoalStore(snapshotStore: JSONSnapshotStore())
            let goal = try goalStore.goal(of: .hero)
            let subtitle = goal.map { goal in
                let lockScreenTitle = goal.lockScreenTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return "戻る先 \(lockScreenTitle.isEmpty ? goal.title : lockScreenTitle)"
            } ?? "なんのために開く？"

            return baseConfiguration(subtitle: subtitle)
        } catch {
            return baseConfiguration(subtitle: nil)
        }
    }

    private func baseConfiguration(subtitle: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: ShieldColors.inkBlack,
            title: ShieldConfiguration.Label(
                text: "ひと呼吸",
                color: ShieldColors.paper
            ),
            subtitle: subtitle.map {
                ShieldConfiguration.Label(
                    text: $0,
                    color: ShieldColors.muted
                )
            },
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "開かない",
                color: ShieldColors.inkBlack
            ),
            primaryButtonBackgroundColor: ShieldColors.electricLime,
            secondaryButtonLabel: nil
        )
    }
}

private enum ShieldColors {
    static let inkBlack = UIColor(red: 10.0 / 255.0, green: 11.0 / 255.0, blue: 13.0 / 255.0, alpha: 1)
    static let paper = UIColor(red: 244.0 / 255.0, green: 245.0 / 255.0, blue: 242.0 / 255.0, alpha: 1)
    static let muted = UIColor(red: 126.0 / 255.0, green: 134.0 / 255.0, blue: 148.0 / 255.0, alpha: 1)
    static let electricLime = UIColor(red: 199.0 / 255.0, green: 249.0 / 255.0, blue: 77.0 / 255.0, alpha: 1)
}
