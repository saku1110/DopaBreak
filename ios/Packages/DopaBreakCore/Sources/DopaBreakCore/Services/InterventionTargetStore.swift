import Foundation

public struct InterventionTargetStore: Sendable {
    private let snapshotStore: JSONSnapshotStore

    public init(snapshotStore: JSONSnapshotStore) {
        self.snapshotStore = snapshotStore
    }

    public func selectedCatalogIDs() throws -> [String] {
        try snapshotStore.read([String].self, from: .interventionTargets) ?? []
    }

    public func selectedTargets() throws -> [SNSAppCatalogItem] {
        try selectedCatalogIDs().compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    public func setTargets(_ catalogIDs: [String]) throws {
        try validate(catalogIDs)
        try snapshotStore.write(catalogIDs, to: .interventionTargets)
    }

    public func deleteAll() throws {
        try snapshotStore.write([String](), to: .interventionTargets)
    }

    private func validate(_ catalogIDs: [String]) throws {
        var seen = Set<String>()
        for catalogID in catalogIDs {
            guard SNSAppCatalog.contains(catalogID: catalogID) else {
                throw CoreError.validation(message: "指定されたアプリが見つかりません")
            }
            guard seen.insert(catalogID).inserted else {
                throw CoreError.validation(message: "同じアプリが重複しています")
            }
        }
    }
}
