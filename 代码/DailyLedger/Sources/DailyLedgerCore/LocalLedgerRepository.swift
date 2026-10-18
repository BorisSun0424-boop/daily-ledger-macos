import Foundation

public enum RepositoryError: Error, Equatable, LocalizedError {
    case unreadableData

    public var errorDescription: String? {
        switch self {
        case .unreadableData:
            return "本地账本文件无法读取，原文件已保留。"
        }
    }
}

public struct LocalLedgerRepository: Sendable {
    public let directoryURL: URL
    public let fileURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.fileURL = directoryURL.appendingPathComponent("ledger.json", isDirectory: false)
    }

    public static func applicationSupport() throws -> LocalLedgerRepository {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return LocalLedgerRepository(directoryURL: base.appendingPathComponent("DailyLedger", isDirectory: true))
    }

    public func load() throws -> LedgerData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LedgerDefaults.emptyData()
        }
        do {
            let bytes = try Data(contentsOf: fileURL)
            return try Self.decoder.decode(LedgerData.self, from: bytes)
        } catch {
            throw RepositoryError.unreadableData
        }
    }

    public func save(_ data: LedgerData) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let bytes = try Self.encoder.encode(data)
        try bytes.write(to: fileURL, options: .atomic)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
