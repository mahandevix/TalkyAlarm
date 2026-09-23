import SwiftUI

/// View for completing a physical challenge to dismiss an alarm
/// Styled with Vibe design system
struct ChallengeView: View {
    let alarm: Alarm
    let motionDetector: MotionDetector
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var showConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: VibeSpacing.lg) {
                // Challenge Header
                VStack(spacing: VibeSpacing.sm) {
                    Image(systemName: challengeIcon)
                        .font(.system(size: 64))
                        .foregroundStyle(VibeColor.accent)
                        .symbolEffect(.bounce, value: motionDetector.currentProgress(challenge: challenge))

                    Text(challenge.title)
                        .font(VibeFont.title)
                        .foregroundStyle(VibeColor.textPrimary)

                    Text(challenge.description)
                        .font(VibeFont.body)
                        .foregroundStyle(VibeColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VibeSpacing.md)
                }
                .padding(VibeSpacing.lg)

                // Progress Card
                VibeCard {
                    VStack(spacing: VibeSpacing.md) {
                        if challenge.isDurationBased {
                            // Plank: Show timer
                            VStack(spacing: VibeSpacing.sm) {
                                Text(L10n.format("challenge.plank_progress", Int(motionDetector.plankDuration)))
                                    .font(VibeFont.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(VibeColor.accent)

                                VibeProgressView(
                                    value: motionDetector.plankDuration,
                                    total: Double(alarm.challengeTarget)
                                )

                                Text(L10n.format("challenge.target_seconds", alarm.challengeTarget))
                                    .font(VibeFont.footnote)
                                    .foregroundStyle(VibeColor.textSecondary)
                            }
                        } else {
                            // Push-ups/Squats: Show counter
                            VStack(spacing: VibeSpacing.sm) {
                                Text(L10n.format("challenge.progress", motionDetector.currentProgress(challenge: challenge), alarm.challengeTarget))
                                    .font(VibeFont.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(VibeColor.accent)

                                VibeProgressView(
                                    value: Double(motionDetector.currentProgress(challenge: challenge)),
                                    total: Double(alarm.challengeTarget)
                                )

                                Text(L10n.format("challenge.target_reps", alarm.challengeTarget))
                                    .font(VibeFont.footnote)
                                    .foregroundStyle(VibeColor.textSecondary)
                            }
                        }
                    }
                }

                // Instructions Card
                VibeCard {
                    VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                        VibeSectionHeader(L10n.tr("challenge.instructions.title"))

                        ForEach(instructions.indices, id: \.self) { index in
                            HStack(spacing: VibeSpacing.sm) {
                                Circle()
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(VibeColor.accent.opacity(0.2))
                                    .overlay(
                                        Circle()
                                            .stroke(VibeColor.accent, lineWidth: 2)
                                            .opacity(motionDetector.hasCompleted(challenge: challenge, target: alarm.challengeTarget) || index < 1 ? 1.0 : 0.3)
                                    )
                                    .overlay(
                                        Text("✓")
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                            .opacity(motionDetector.hasCompleted(challenge: challenge, target: alarm.challengeTarget) ? 1.0 : 0.0)
                                    )

                                Text(instructions[index])
                                    .font(VibeFont.footnote)
                                    .foregroundStyle(VibeColor.textSecondary)
                            }
                        }
                    }
                }

                Spacer()

                // Action Buttons
                HStack(spacing: VibeSpacing.md) {
                    Button(L10n.tr("common.cancel")) {
                        onCancel()
                    }
                    .vibeSecondaryButton()

                    if motionDetector.hasCompleted(challenge: challenge, target: alarm.challengeTarget) {
                        Button {
                            showConfirmation = true
                        } label: {
                            Label(L10n.tr("challenge.complete"), systemImage: "checkmark.circle.fill")
                                .font(VibeFont.headline)
                        }
                        .vibePrimaryButton()
                        .disabled(!motionDetector.hasCompleted(challenge: challenge, target: alarm.challengeTarget))
                        .opacity(motionDetector.hasCompleted(challenge: challenge, target: alarm.challengeTarget) ? 1.0 : 0.6)
                    } else {
                        Button {
                            // Keep trying - do nothing, just visual feedback
                        } label: {
                            Label(L10n.tr("challenge.keep_going"), systemImage: "arrow.clockwise")
                                .font(VibeFont.headline)
                        }
                        .vibePrimaryButton()
                    }
                }
                .padding(.horizontal, VibeSpacing.md)
            }
            .padding(.top, VibeSpacing.lg)
            .padding(.bottom, VibeSpacing.md)
        }
        .background(VibeColor.background)
        .navigationTitle(L10n.tr("challenge.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            motionDetector.startDetecting(for: challenge, target: alarm.challengeTarget)
        }
        .onDisappear {
            motionDetector.stopDetection()
        }
        .alert(
            L10n.tr("challenge.complete_title"),
            isPresented: $showConfirmation
        ) {
            Button(L10n.tr("common.yes"), role: .destructive) {
                motionDetector.stopDetection()
                onComplete()
            }
            Button(L10n.tr("common.no"), role: .cancel) {}
        } message: {
            Text(L10n.tr("challenge.complete_message"))
        }
    }

    private var challenge: PhysicalChallenge {
        alarm.challenge ?? .pushUps
    }

    private var challengeIcon: String {
        switch challenge {
        case .pushUps:
            return "figure.arms"
        case .squats:
            return "figure.walk"
        case .plank:
            return "figure.core.training"
        }
    }

    private var instructions: [String] {
        switch challenge {
        case .pushUps:
            return [
                L10n.tr("challenge.push_ups_instruction_1"),
                L10n.tr("challenge.push_ups_instruction_2"),
                L10n.tr("challenge.push_ups_instruction_3")
            ]
        case .squats:
            return [
                L10n.tr("challenge.squats_instruction_1"),
                L10n.tr("challenge.squats_instruction_2"),
                L10n.tr("challenge.squats_instruction_3")
            ]
        case .plank:
            return [
                L10n.tr("challenge.plank_instruction_1"),
                L10n.tr("challenge.plank_instruction_2"),
                L10n.tr("challenge.plank_instruction_3")
            ]
        }
    }
}

// Preview
#Preview {
    let alarm = Alarm(
        title: "Morning Workout",
        hour: 7,
        minute: 30,
        challenge: .pushUps,
        challengeTarget: 10
    )
    let detector = MotionDetector()
    return NavigationStack {
        ChallengeView(alarm: alarm, motionDetector: detector, onComplete: {}, onCancel: {})
            .background(VibeColor.background)
    }
}
