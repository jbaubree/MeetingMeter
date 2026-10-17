import Foundation

public final class MeetingHistoryStore {
    public let directoryURL: URL
    public let fileURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.fileURL = directoryURL.appendingPathComponent("history.json")
    }

    public convenience init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("MeetingMeter", isDirectory: true)
        self.init(directoryURL: base)
    }

    public func loadAll() -> [MeetingRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([MeetingRecord].self, from: data)) ?? []
    }

    public func append(_ record: MeetingRecord) {
        var all = loadAll()
        all.append(record)
        save(all)
    }

    public func clear() {
        save([])
    }

    private func save(_ records: [MeetingRecord]) {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
