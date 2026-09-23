import AVFoundation
import Foundation

@MainActor
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    func preview(sentence: String, voice: AlarmVoice, tier: SubscriptionTier) {
        let usePremium = (voice == .premiumTTS && tier == .pro)
        if let motivationalSound = voice.motivationalSound {
            speak(sentence: motivationalSound.sentence, usePremiumVoice: usePremium)
        } else {
            speak(sentence: sentence, usePremiumVoice: usePremium)
        }
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
    
    // For challenge-based alarms
    private var currentChallengeAlarm: Alarm?
    private var motionDetector = MotionDetector()

    func play(alarm: Alarm, recordingsDirectory: URL) {
        stop()
        configureAudioSession()

        if alarm.voice == .recorded,
           let fileName = alarm.recordingFileName,
           let recordedURL = recordingURL(named: fileName, in: recordingsDirectory) {
            playRecorded(from: recordedURL, gradualVolume: alarm.gradualVolume)
            return
        }

        if let motivationalSound = alarm.voice.motivationalSound {
            speak(sentence: motivationalSound.sentence, usePremiumVoice: alarm.voice == .premiumTTS, gradualVolume: alarm.gradualVolume)
        } else {
            speak(sentence: alarm.spokenSentence, usePremiumVoice: alarm.voice == .premiumTTS, gradualVolume: alarm.gradualVolume)
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        motionDetector.stopDetection()
        currentChallengeAlarm = nil
    }
    
    /// Play alarm with challenge - shows challenge UI instead of playing sound immediately
    func playWithChallenge(alarm: Alarm, recordingsDirectory: URL) {
        stop()
        currentChallengeAlarm = alarm
        motionDetector.startDetecting(for: alarm.challenge ?? .pushUps, target: alarm.challengeTarget)
        configureAudioSession()
        
        // Play a brief initial sound to get attention
        if alarm.voice == .recorded,
           let fileName = alarm.recordingFileName,
           let recordedURL = recordingURL(named: fileName, in: recordingsDirectory) {
            playRecorded(from: recordedURL, gradualVolume: alarm.gradualVolume, volume: 0.3)
            return
        }
        
        if let motivationalSound = alarm.voice.motivationalSound {
            speak(sentence: motivationalSound.sentence, usePremiumVoice: alarm.voice == .premiumTTS, gradualVolume: alarm.gradualVolume, volume: 0.3)
        } else {
            speak(sentence: alarm.spokenSentence, usePremiumVoice: alarm.voice == .premiumTTS, gradualVolume: alarm.gradualVolume, volume: 0.3)
        }
    }
    
    /// Check if current challenge is completed
    func isChallengeCompleted() -> Bool {
        guard let alarm = currentChallengeAlarm else { return false }
        return motionDetector.hasCompleted(challenge: alarm.challenge ?? .pushUps, target: alarm.challengeTarget)
    }
    
    /// Get current challenge progress
    func getChallengeProgress() -> (current: Int, target: Int) {
        guard let alarm = currentChallengeAlarm else { return (0, 0) }
        return (motionDetector.currentProgress(challenge: alarm.challenge ?? .pushUps), alarm.challengeTarget)
    }
    
    /// Get current challenge
    func getCurrentChallenge() -> PhysicalChallenge? {
        return currentChallengeAlarm?.challenge
    }
    
    /// Dismiss current challenge
    func dismissChallenge() {
        currentChallengeAlarm = nil
        motionDetector.stopDetection()
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

    private func speak(sentence: String, usePremiumVoice: Bool, gradualVolume: Bool, volume: Float = 1.0) {
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.rate = 0.48
        utterance.voice = bestVoice(usePremium: usePremiumVoice)

        // AVSpeechSynthesizer does not support true runtime volume ramping.
        utterance.volume = gradualVolume ? (volume * 0.45) : volume
        synthesizer.speak(utterance)
    }
    
    private func playRecorded(from url: URL, gradualVolume: Bool, volume: Float = 1.0) {
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }
        player.prepareToPlay()
        player.volume = gradualVolume ? (volume * 0.08) : volume
        player.play()
        audioPlayer = player

        if gradualVolume {
            player.setVolume(volume, fadeDuration: 24)
        }
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
