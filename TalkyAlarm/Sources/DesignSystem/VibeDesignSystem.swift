import SwiftUI

// MARK: - Vibe Design System
// A modern, clean design system inspired by Vibe app aesthetic
// Used throughout TalkyAlarm for consistent styling

/// Color palette for Vibe-inspired design
public enum VibeColor {
    /// Primary accent color - vibrant blue
    public static let accent = Color("VibeAccent", bundle: .main) ?? Color(red: 0.4, green: 0.6, blue: 1.0)
    
    /// Secondary accent color - purple
    public static let accentSecondary = Color("VibeAccentSecondary", bundle: .main) ?? Color(red: 0.6, green: 0.4, blue: 1.0)
    
    /// Background color for screens
    public static let background = Color("VibeBackground", bundle: .main) ?? Color(red: 0.98, green: 0.98, blue: 0.99)
    
    /// Card/container background
    public static let cardBackground = Color("VibeCardBackground", bundle: .main) ?? Color.white
    
    /// Primary text color
    public static let textPrimary = Color.primary
    
    /// Secondary text color
    public static let textSecondary = Color.secondary
    
    /// Success state color
    public static let success = Color.green
    
    /// Warning state color
    public static let warning = Color.orange
    
    /// Error state color
    public static let error = Color.red
    
    /// Border color
    public static let border = Color.gray.opacity(0.2)
}

/// Spacing values for consistent layout
public enum VibeSpacing {
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

/// Typography styles
public enum VibeFont {
    public static let largeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
    public static let title = Font.system(size: 24, weight: .bold, design: .rounded)
    public static let title2 = Font.system(size: 20, weight: .semibold, design: .rounded)
    public static let title3 = Font.system(size: 18, weight: .semibold, design: .rounded)
    public static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    public static let body = Font.system(size: 15, weight: .regular, design: .rounded)
    public static let callout = Font.system(size: 14, weight: .regular, design: .rounded)
    public static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
    public static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
    public static let caption2 = Font.system(size: 10, weight: .regular, design: .rounded)
}

/// Corner radius values
public enum VibeCornerRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 28
    public static let full: CGFloat = .infinity
}

/// Shadow styles
public enum VibeShadow {
    public static let none: ShadowStyle = .none
    
    public static let sm: ShadowStyle = .drop(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    
    public static let md: ShadowStyle = .drop(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    
    public static let lg: ShadowStyle = .drop(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
    
    public static let accentGlow: ShadowStyle = .drop(color: VibeColor.accent.opacity(0.3), radius: 8, x: 0, y: 4)
}

// MARK: - Reusable Components

/// A card component with Vibe styling
public struct VibeCard<Content: View>: View {
    private let content: Content
    private let padding: EdgeInsets
    private let shadow: ShadowStyle
    private let cornerRadius: CGFloat
    
    public init(
        padding: EdgeInsets = EdgeInsets(
            top: VibeSpacing.md,
            leading: VibeSpacing.md,
            bottom: VibeSpacing.md,
            trailing: VibeSpacing.md
        ),
        shadow: ShadowStyle = VibeShadow.md,
        cornerRadius: CGFloat = VibeCornerRadius.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.shadow = shadow
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        content
            .padding(padding)
            .background(VibeColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(style: shadow)
    }
}

/// Primary button style matching Vibe aesthetic
public struct VibePrimaryButton: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VibeFont.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(VibeSpacing.md)
            .background(VibeColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: VibeCornerRadius.md))
            .shadow(style: VibeShadow.accentGlow)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Secondary button style
public struct VibeSecondaryButton: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VibeFont.headline)
            .foregroundStyle(VibeColor.accent)
            .frame(maxWidth: .infinity)
            .padding(VibeSpacing.md)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: VibeCornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: VibeCornerRadius.md)
                    .stroke(VibeColor.accent, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Tertiary button style (text only)
public struct VibeTertiaryButton: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VibeFont.body)
            .foregroundStyle(VibeColor.accent)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// Destructive button style
public struct VibeDestructiveButton: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VibeFont.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(VibeSpacing.md)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: VibeCornerRadius.md))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Icon button style
public struct VibeIconButton: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(VibeColor.accent)
            .padding(VibeSpacing.sm)
            .background(
                Circle()
                    .fill(Color.white)
                    .shadow(style: VibeShadow.sm)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// Section header view
public struct VibeSectionHeader: View {
    private let title: String
    private let subtitle: String?
    
    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.xs) {
            Text(title)
                .font(VibeFont.headline)
                .foregroundStyle(VibeColor.textPrimary)
            
            if let subtitle {
                Text(subtitle)
                    .font(VibeFont.footnote)
                    .foregroundStyle(VibeColor.textSecondary)
            }
        }
    }
}

/// Progress view with Vibe styling
public struct VibeProgressView: View {
    private let value: Double
    private let total: Double
    private let height: CGFloat
    private let cornerRadius: CGFloat
    
    public init(value: Double, total: Double, height: CGFloat = 8, cornerRadius: CGFloat = 4) {
        self.value = value
        self.total = total
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .frame(width: geometry.size.width, height: height)
                    .foregroundStyle(VibeColor.border)
                
                // Progress fill
                RoundedRectangle(cornerRadius: cornerRadius)
                    .frame(width: min(CGFloat(value / total) * geometry.size.width, geometry.size.width), height: height)
                    .foregroundStyle(VibeColor.accent)
                    .animation(.smooth, value: value)
            }
        }
        .frame(height: height)
    }
}

/// Badge/pill component
public struct VibeBadge: View {
    private let text: String
    private let color: Color
    
    public init(_ text: String, color: Color = VibeColor.accent) {
        self.text = text
        self.color = color
    }
    
    public var body: some View {
        Text(text)
            .font(VibeFont.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, VibeSpacing.sm)
            .padding(.vertical, VibeSpacing.xs)
            .background(color)
            .clipShape(Capsule())
    }
}

/// Divider with Vibe styling
public struct VibeDivider: View {
    public init() {}
    
    public var body: some View {
        Rectangle()
            .fill(VibeColor.border)
            .frame(height: 1)
            .padding(.vertical, VibeSpacing.sm)
    }
}

// MARK: - Extensions

public extension View {
    /// Applies Vibe card styling
    func vibeCard(padding: EdgeInsets = EdgeInsets(top: VibeSpacing.md, leading: VibeSpacing.md, bottom: VibeSpacing.md, trailing: VibeSpacing.md)) -> some View {
        self.modifier(VibeCardModifier(padding: padding))
    }
    
    /// Applies Vibe primary button styling
    func vibePrimaryButton() -> some View {
        self.buttonStyle(VibePrimaryButton())
    }
    
    /// Applies Vibe secondary button styling
    func vibeSecondaryButton() -> some View {
        self.buttonStyle(VibeSecondaryButton())
    }
    
    /// Applies Vibe tertiary button styling
    func vibeTertiaryButton() -> some View {
        self.buttonStyle(VibeTertiaryButton())
    }
    
    /// Applies Vibe destructive button styling
    func vibeDestructiveButton() -> some View {
        self.buttonStyle(VibeDestructiveButton())
    }
    
    /// Applies Vibe icon button styling
    func vibeIconButton() -> some View {
        self.buttonStyle(VibeIconButton())
    }
}

private struct VibeCardModifier: ViewModifier {
    let padding: EdgeInsets
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(VibeColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: VibeCornerRadius.lg))
            .shadow(style: VibeShadow.md)
    }
}

// MARK: - Preview

#Preview {
    VibeDesignSystemPreview()
}

struct VibeDesignSystemPreview: View {
    @State private var progress: Double = 0.6
    
    var body: some View {
        ScrollView {
            VStack(spacing: VibeSpacing.lg) {
                // Colors
                VibeCard {
                    VStack(alignment: .leading, spacing: VibeSpacing.md) {
                        Text("Colors")
                            .font(VibeFont.title2)
                        
                        HStack(spacing: VibeSpacing.md) {
                            VStack {
                                Rectangle()
                                    .fill(VibeColor.accent)
                                    .frame(height: 60)
                                Text("Accent")
                                    .font(VibeFont.footnote)
                            }
                            
                            VStack {
                                Rectangle()
                                    .fill(VibeColor.accentSecondary)
                                    .frame(height: 60)
                                Text("Secondary")
                                    .font(VibeFont.footnote)
                            }
                            
                            VStack {
                                Rectangle()
                                    .fill(VibeColor.success)
                                    .frame(height: 60)
                                Text("Success")
                                    .font(VibeFont.footnote)
                            }
                        }
                    }
                }
                
                // Typography
                VibeCard {
                    VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                        Text("Typography")
                            .font(VibeFont.title2)
                        
                        Text("Large Title")
                            .font(VibeFont.largeTitle)
                        
                        Text("Title")
                            .font(VibeFont.title)
                        
                        Text("Title 2")
                            .font(VibeFont.title2)
                        
                        Text("Headline")
                            .font(VibeFont.headline)
                        
                        Text("Body")
                            .font(VibeFont.body)
                        
                        Text("Footnote")
                            .font(VibeFont.footnote)
                        
                        Text("Caption")
                            .font(VibeFont.caption)
                    }
                }
                
                // Buttons
                VibeCard {
                    VStack(spacing: VibeSpacing.md) {
                        Text("Buttons")
                            .font(VibeFont.title2)
                        
                        Button("Primary") { }
                            .vibePrimaryButton()
                        
                        Button("Secondary") { }
                            .vibeSecondaryButton()
                        
                        Button("Tertiary") { }
                            .vibeTertiaryButton()
                        
                        Button("Destructive") { }
                            .vibeDestructiveButton()
                        
                        HStack(spacing: VibeSpacing.md) {
                            Button { } label: {
                                Image(systemName: "plus")
                            }
                            .vibeIconButton()
                            
                            Button { } label: {
                                Image(systemName: "heart.fill")
                            }
                            .vibeIconButton()
                        }
                    }
                }
                
                // Progress
                VibeCard {
                    VStack(spacing: VibeSpacing.md) {
                        Text("Progress: \(Int(progress * 100))%")
                            .font(VibeFont.headline)
                        
                        VibeProgressView(value: progress, total: 1.0, height: 12)
                        
                        Button("Animate") {
                            withAnimation(.smooth) {
                                progress = progress >= 1.0 ? 0 : 1.0
                            }
                        }
                        .vibePrimaryButton()
                    }
                }
                
                // Badges
                VibeCard {
                    VStack(alignment: .leading, spacing: VibeSpacing.md) {
                        Text("Badges")
                            .font(VibeFont.title2)
                        
                        HStack(spacing: VibeSpacing.md) {
                            VibeBadge("New")
                            VibeBadge("Pro", color: VibeColor.accentSecondary)
                            VibeBadge("Free", color: VibeColor.success)
                        }
                    }
                }
            }
            .padding(VibeSpacing.lg)
        }
        .background(VibeColor.background)
    }
}
