import AVFoundation
import Foundation

@MainActor
final class AudioRecorderService {
    private var recorder: AVAudioRecorder?
    private(set) var isRecording = false
    let recordingsDirectory: URL

    init(fileManager: FileManager = .default) {
        let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        recordingsDirectory = libraryDirectory.appendingPathComponent("Sounds", isDirectory: true)
        try? fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start(fileName: String) throws -> URL {
        let url = recordingsDirectory.appendingPathComponent(fileName).appendingPathExtension("caf")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleIMA4),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 12_800
        ]

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.prepareToRecord()
        recorder?.record()
        isRecording = true
        return url
    }

    func stop() -> URL? {
        guard let recorder else { return nil }
        recorder.stop()
        isRecording = false
        self.recorder = nil
        return recorder.url
    }
}
