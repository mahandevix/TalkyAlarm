import Foundation

final class AlarmStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let appDirectory = supportDirectory.appendingPathComponent("TalkyAlarm", isDirectory: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        fileURL = appDirectory.appendingPathComponent("alarms.json")
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    }

    func load() -> [Alarm] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([Alarm].self, from: data)) ?? []
    }

    func save(_ alarms: [Alarm]) throws {
        let data = try encoder.encode(alarms)
        try data.write(to: fileURL, options: [.atomic])
    }
}
