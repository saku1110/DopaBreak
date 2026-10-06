import DopaBreakCore
import FamilyControls
import ManagedSettings
import SwiftUI

struct ReinterventionSettingsView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var state = ReinterventionState()
    @State private var connecting: SNSAppCatalogItem?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(String(localized: "reintervention.setup.description", defaultValue: "利用目的に合わせて、選んだ時間で確認通知またはブロックを行います。必要な用事は通知が基本で、ブロックした場合は戻って振り返れます。"))
                    .foregroundStyle(DesignTokens.secondaryText)
                Text(String(localized: "reintervention.setup.mapping", defaultValue: "はじめに対象と同じアプリを1つ選んで接続してください。iOSの仕様上、正しいアプリが選ばれたかをDopaBreak側で自動確認することはできません。"))
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.secondaryText)
                if let error { Text(error).foregroundStyle(DesignTokens.danger) }
                ForEach(model.selectedReinterventionTargets, id: \.catalogID) { target in
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(target.displayName).dopaFont(18, weight: .bold)
                            if let data = state.selections[target.catalogID], let token = ReinterventionShield.tokens(in: data).first {
                                Label(token).labelStyle(.titleAndIcon)
                                Text(String(localized: "reintervention.setup.connected", defaultValue: "接続済み・次に利用時間を選ぶと開始"))
                                    .font(.footnote).foregroundStyle(DesignTokens.secondaryText)
                                if let session = state.sessions[target.catalogID] {
                                    Text(session.isBlocking
                                        ? String(localized: "reintervention.setup.budget", defaultValue: "\(session.minutes)分の利用で通知・制限")
                                        : String(localized: "reintervention.soft.budget", defaultValue: "\(session.minutes)分の利用で確認通知"))
                                    Button(session.isBlocking
                                        ? String(localized: "reintervention.setup.finish", defaultValue: "ここで終了して振り返る")
                                        : String(localized: "reintervention.soft.finish", defaultValue: "ここで計測を終了")) {
                                        perform { try model.requestEarlyReinterventionReview(catalogID: target.catalogID); dismiss() }
                                    }
                                }
                                Button(String(localized: "reintervention.setup.disconnect", defaultValue: "通知・制限の接続を解除"), role: .destructive) {
                                    perform { try model.finishReintervention(catalogID: target.catalogID, disconnect: true) }
                                }
                            } else {
                                Button(String(localized: "reintervention.setup.connect", defaultValue: "アプリを接続")) {
                                    Task {
                                        guard #available(iOS 17.4, *) else { error = ReinterventionError.setup.localizedDescription; return }
                                        if await model.requestScreenTimeAuthorization() { connecting = target }
                                        else { error = ReinterventionError.setup.localizedDescription }
                                    }
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                if model.selectedReinterventionTargets.isEmpty {
                    Text(String(localized: "reintervention.setup.empty", defaultValue: "先に「一呼吸」の対象アプリを追加してください。"))
                }
                Text(String(localized: "reintervention.setup.limit", defaultValue: "実際の利用時間を累計します。iOSの仕様により通知や制限に遅延が生じる場合があります。12時間以内に指定した時間へ達しなかった計測は終了します。DopaBreak自身は選ばないでください。"))
                    .font(.footnote).foregroundStyle(DesignTokens.secondaryText)
            }
            .padding(20)
        }
        .navigationTitle(String(localized: "reintervention.title", defaultValue: "利用時間の通知・制限"))
        .navigationBarTitleDisplayMode(.inline)
        .dopaScreenBackground()
        .tint(DesignTokens.accent)
        .onAppear { reload() }
        .onChange(of: connecting != nil) { _, visible in model.isChildModalActive = visible }
        .sheet(item: $connecting, onDismiss: reload) { target in
            ReinterventionConnectionSheet(model: model, target: target)
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action(); error = nil; reload() } catch { self.error = error.localizedDescription }
    }
    private func reload() {
        do { state = try model.reinterventionScheduler.store.read() } catch { self.error = error.localizedDescription }
    }
}

private struct ReinterventionConnectionSheet: View {
    let model: AppModel
    let target: SNSAppCatalogItem
    @Environment(\.dismiss) private var dismiss
    @State private var selection = FamilyActivitySelection()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle(target.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    Text(error ?? String(localized: "reintervention.setup.select_one", defaultValue: "上に表示されたアプリを1つだけ選んでください"))
                        .font(.footnote).padding().frame(maxWidth: .infinity).background(.regularMaterial)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "reintervention.setup.cancel", defaultValue: "キャンセル")) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "reintervention.setup.save", defaultValue: "接続する")) {
                            do { try model.connectReintervention(catalogID: target.catalogID, selection: selection); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                }
        }
    }
}
