import DopaBreakCore
import SwiftUI

/// 止めるアプリ（通常介入の対象）をカタログから複数選択するシート（doc12 §3 / doc11 §4c）。
/// Freeは初回14日間3個、その後1個。上限到達後の追加でPaywallを表示する。
struct TargetAppPickerSheet: View {
    let model: AppModel
    let onPaywallNeeded: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCatalogIDs: [String] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "target_app_picker.title", defaultValue: "止めるアプリを選ぶ"))
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(DesignTokens.primaryText)

                    Text(String(localized: "target_app_picker.description", defaultValue: "開こうとした瞬間に一呼吸を出したいアプリを選びます。"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineSpacing(4)

                    if let targetLimitDescription {
                        Text(targetLimitDescription)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignTokens.secondaryText)
                    }

                    CardContainer {
                        VStack(spacing: 0) {
                            ForEach(Array(SNSAppCatalog.all.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    divider
                                }
                                appRow(item)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignTokens.danger)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 60)
            }
            .dopaScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "target_app_picker.action.close", defaultValue: "閉じる")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.secondaryText)
                }
            }
        }
        .tint(DesignTokens.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            selectedCatalogIDs = (try? model.targetStore.selectedCatalogIDs()) ?? []
        }
    }

    private func appRow(_ item: SNSAppCatalogItem) -> some View {
        let isSelected = selectedCatalogIDs.contains(item.catalogID)
        return Button {
            toggle(item)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.primaryText)
                    .frame(width: 32, height: 32)
                    .background(DesignTokens.backgroundRaised)
                    .clipShape(Circle())

                Text(item.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryText)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? DesignTokens.accent : DesignTokens.secondaryText)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignTokens.hairline)
            .frame(height: 1)
    }

    private var targetLimitDescription: String? {
        switch model.entitlementGate.targetAppTokensLimit {
        case 3:
            return String(
                localized: "target_app_picker.limit.trial",
                defaultValue: "はじめの14日は3つまで追加できます"
            )
        case 1:
            return String(localized: "target_app_picker.limit.free", defaultValue: "無料プランでは1つまで")
        default:
            return nil
        }
    }

    private func toggle(_ item: SNSAppCatalogItem) {
        errorMessage = nil

        if selectedCatalogIDs.contains(item.catalogID) {
            selectedCatalogIDs.removeAll { $0 == item.catalogID }
            persist()
            return
        }

        guard model.entitlementGate.canAddTargetTokens(currentCount: selectedCatalogIDs.count) else {
            onPaywallNeeded()
            dismiss()
            return
        }

        selectedCatalogIDs.append(item.catalogID)
        persist()
    }

    private func persist() {
        do {
            try model.setTargetCatalogIDs(selectedCatalogIDs)
        } catch CoreError.validation(let message) {
            errorMessage = message
        } catch {
            errorMessage = String(localized: "target_app_picker.error.save", defaultValue: "保存できませんでした")
        }
    }
}
