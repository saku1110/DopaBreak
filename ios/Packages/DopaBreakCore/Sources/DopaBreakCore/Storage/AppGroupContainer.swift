import Foundation

public protocol ContainerProviding: Sendable {
    func containerURL() throws -> URL
}

public struct AppGroupContainer: ContainerProviding {
    public init() {}

    public func containerURL() throws -> URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            throw CoreError.appGroupUnavailable(AppGroup.identifier)
        }
        return url
    }
}

public struct FixedContainer: ContainerProviding {
    public var url: URL

    public init(url: URL) {
        self.url = url
    }

    public func containerURL() throws -> URL {
        url
    }
}
