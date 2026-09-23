import CoreMotion
import Foundation

/// Detects physical motion patterns using the device's accelerometer
@MainActor
final class MotionDetector: NSObject, ObservableObject {
    private let motionManager = CMMotionActivityManager()
    private let accelerometer = CMAccelerometer()
    private var motionQueue: OperationQueue?
    private var accelerometerQueue: OperationQueue?

    @Published private(set) var pushUpCount = 0
    @Published private(set) var squatCount = 0
    @Published private(set) var isPlanking = false
    @Published private(set) var plankDuration: TimeInterval = 0
    @Published private(set) var isDetecting = false

    private var plankStartTime: Date?
    private var lastAcceleration: CMAcceleration?
    private var detectionTimer: Timer?

    override init() {
        super.init()
        setupQueues()
    }

    deinit {
        stopDetection()
    }

    private func setupQueues() {
        motionQueue = OperationQueue()
        motionQueue?.qualityOfService = .utility

        accelerometerQueue = OperationQueue()
        accelerometerQueue?.qualityOfService = .utility
    }

    /// Start detecting motion for a specific challenge
    func startDetecting(for challenge: PhysicalChallenge, target: Int) {
        stopDetection()
        resetCounts()
        isDetecting = true

        switch challenge {
        case .pushUps:
            startPushUpDetection()
        case .squats:
            startSquatDetection()
        case .plank:
            startPlankDetection()
        }
    }

    /// Stop all motion detection
    func stopDetection() {
        isDetecting = false
        accelerometer.stopAccelerometerUpdates()
        detectionTimer?.invalidate()
        detectionTimer = nil
        plankStartTime = nil
    }

    private func resetCounts() {
        pushUpCount = 0
        squatCount = 0
        isPlanking = false
        plankDuration = 0
        lastAcceleration = nil
    }

    // MARK: - Push-up Detection

    private func startPushUpDetection() {
        guard let queue = accelerometerQueue else { return }

        accelerometer.startAccelerometerUpdates(to: queue) { [weak self] data, error in
            guard let self, let data else { return }

            let acceleration = data.acceleration

            // Push-up detection logic:
            // Look for the pattern: down (negative Y), up (positive Y)
            // We track the direction changes
            if let last = self.lastAcceleration {
                // Detect going down (Y decreases significantly)
                if last.y > 0 && acceleration.y < -0.5 && last.y - acceleration.y > 1.0 {
                    self.lastAcceleration = acceleration
                    return
                }

                // Detect coming up (Y increases significantly from negative)
                if last.y < -0.5 && acceleration.y > 0 && acceleration.y - last.y > 1.0 {
                    DispatchQueue.main.async {
                        self.pushUpCount += 1
                    }
                }
            }

            self.lastAcceleration = acceleration
        }
    }

    // MARK: - Squat Detection

    private func startSquatDetection() {
        guard let queue = accelerometerQueue else { return }

        accelerometer.startAccelerometerUpdates(to: queue) { [weak self] data, error in
            guard let self, let data else { return }

            let acceleration = data.acceleration

            // Squat detection logic:
            // Look for the pattern: standing (Z ~ -1), squatting (Z ~ 0), standing (Z ~ -1)
            // We track Z-axis changes
            if let last = self.lastAcceleration {
                // Detect squatting down (Z increases toward 0)
                if last.z < -0.5 && acceleration.z > -0.2 && acceleration.z - last.z > 0.5 {
                    self.lastAcceleration = acceleration
                    return
                }

                // Detect standing up (Z decreases back to -1)
                if last.z > -0.5 && acceleration.z < -0.5 && last.z - acceleration.z > 0.5 {
                    DispatchQueue.main.async {
                        self.squatCount += 1
                    }
                }
            }

            self.lastAcceleration = acceleration
        }
    }

    // MARK: - Plank Detection

    private func startPlankDetection() {
        guard let queue = accelerometerQueue else { return }

        accelerometer.startAccelerometerUpdates(to: queue) { [weak self] data, error in
            guard let self, let data else { return }

            let acceleration = data.acceleration

            // Plank detection logic:
            // In plank position, X and Y should be close to 0, Z should be close to -1
            // and the device should be relatively stable
            let isStable = abs(acceleration.x) < 0.3 && abs(acceleration.y) < 0.3
            let isFaceDown = acceleration.z < -0.7

            if isStable && isFaceDown {
                // Device is in plank position
                if !self.isPlanking {
                    self.isPlanking = true
                    self.plankStartTime = Date()
                    self.startPlankTimer()
                }
            } else {
                if self.isPlanking {
                    self.isPlanking = false
                    self.plankStartTime = nil
                }
            }

            self.lastAcceleration = acceleration
        }
    }

    private func startPlankTimer() {
        detectionTimer?.invalidate()
        detectionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.plankStartTime else { return }
            self.plankDuration = Date().timeIntervalSince(startTime)
        }
    }

    // MARK: - Target Completion Check

    func hasCompleted(challenge: PhysicalChallenge, target: Int) -> Bool {
        switch challenge {
        case .pushUps:
            return pushUpCount >= target
        case .squats:
            return squatCount >= target
        case .plank:
            return plankDuration >= Double(target)
        }
    }

    func currentProgress(challenge: PhysicalChallenge) -> Int {
        switch challenge {
        case .pushUps:
            return pushUpCount
        case .squats:
            return squatCount
        case .plank:
            return Int(plankDuration)
        }
    }
}
