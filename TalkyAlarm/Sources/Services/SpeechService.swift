import AVFoundation
import Foundation

@MainActor
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    func preview(sentence: String, voice: AlarmVoice, tier: SubscriptionTier) {
        let usePremium = (voice == .premiumTTS && tier == .pro)
        speak(sentence: sentence, usePremiumVoice: usePremium)
    }

    func speak(sentence: String, usePremiumVoice: Bool) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.rate = 0.48
        utterance.voice = bestVoice(usePremium: usePremiumVoice)
        synthesizer.speak(utterance)
    }

    private func bestVoice(usePremium: Bool) -> AVSpeechSynthesisVoice? {
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en-US"
        let voices = AVSpeechSynthesisVoice.speechVoices()

        if usePremium,
           let premium = voices.first(where: { $0.language.hasPrefix(currentLanguage) && $0.quality == .enhanced }) {
            return premium
        }

        return voices.first(where: { $0.language.hasPrefix(currentLanguage) })
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

@MainActor
final class AlarmPlaybackService {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?

    func play(alarm: Alarm, recordingsDirectory: URL) {
        stop()
        configureAudioSession()

        if alarm.voice == .recorded,
           let fileName = alarm.recordingFileName,
           let recordedURL = recordingURL(named: fileName, in: recordingsDirectory) {
            playRecorded(from: recordedURL, gradualVolume: alarm.gradualVolume)
            return
        }

        speak(sentence: alarm.spokenSentence, usePremiumVoice: alarm.voice == .premiumTTS, gradualVolume: alarm.gradualVolume)
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func recordingURL(named fileName: String, in directory: URL) -> URL? {
        let url = directory.appendingPathComponent(fileName).appendingPathExtension("caf")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func playRecorded(from url: URL, gradualVolume: Bool) {
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }
        player.prepareToPlay()
        player.volume = gradualVolume ? 0.08 : 1.0
        player.play()
        audioPlayer = player

        if gradualVolume {
            player.setVolume(1.0, fadeDuration: 24)
        }
    }

    private func speak(sentence: String, usePremiumVoice: Bool, gradualVolume: Bool) {
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.rate = 0.48
        utterance.voice = bestVoice(usePremium: usePremiumVoice)

        // AVSpeechSynthesizer does not support true runtime volume ramping.
        utterance.volume = gradualVolume ? 0.45 : 1.0
        synthesizer.speak(utterance)
    }

    private func bestVoice(usePremium: Bool) -> AVSpeechSynthesisVoice? {
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en-US"
        let voices = AVSpeechSynthesisVoice.speechVoices()

        if usePremium,
           let premium = voices.first(where: { $0.language.hasPrefix(currentLanguage) && $0.quality == .enhanced }) {
            return premium
        }

        return voices.first(where: { $0.language.hasPrefix(currentLanguage) })
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}
