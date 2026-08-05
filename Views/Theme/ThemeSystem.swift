//
//  ThemeSystem.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI

// MARK: - Custom Color Extension

extension Color {
    static let emerald = Color(red: 0.05, green: 0.75, blue: 0.5)
}

// MARK: - Premium Top Gradient Wash

/// A subtle, dual-tone gradient wash that sits at the top of each screen.
/// Creates a premium ambient glow behind Liquid Glass surfaces.
struct TopGradientWash: View {
    var tint: Color = .indigo
    var secondaryTint: Color = .purple

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            // Primary elliptical wash — left-biased
            EllipticalGradient(
                colors: [
                    tint.opacity(colorScheme == .dark ? 0.5 : 0.3),
                    tint.opacity(colorScheme == .dark ? 0.2 : 0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.25, y: 0.0),
                startRadiusFraction: 0.0,
                endRadiusFraction: 0.7
            )

            // Secondary accent wash — right-biased
            EllipticalGradient(
                colors: [
                    secondaryTint.opacity(colorScheme == .dark ? 0.3 : 0.15),
                    .clear
                ],
                center: UnitPoint(x: 0.85, y: 0.0),
                startRadiusFraction: 0.0,
                endRadiusFraction: 0.45
            )
        }
        .frame(height: 420)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Native Liquid Glass Card Modifier (iOS 26+)

/// Applies the system `glassEffect` for static content cards.
struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

/// Applies an interactive glass effect for tappable / pressable surfaces.
/// Provides native scale-on-press, bounce, and touch-point illumination.
struct GlassInteractiveCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    /// Native liquid glass card — uses the system `glassEffect` API.
    func appleCardStyle(cornerRadius: CGFloat = 22) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }

    /// Interactive liquid glass card — for tappable surfaces with press feedback.
    func interactiveGlassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassInteractiveCardModifier(cornerRadius: cornerRadius))
    }

    /// Clear glass for subtle translucent chips and inner elements.
    func clearGlassCard(cornerRadius: CGFloat = 18) -> some View {
        self.glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
    }

    /// Clear glass capsule for pill-shaped elements.
    func clearGlassCapsule() -> some View {
        self.glassEffect(.clear, in: .capsule)
    }
}

// MARK: - Button Styles

/// A lightweight button style that scales content slightly while pressed.
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Interactive Glass Action Button

/// A pill-shaped action button using native liquid glass.
struct GlassActionButton: View {
    let title: String
    let systemImage: String
    var accentColor: Color = .indigo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .imageScale(.small)
        }
        .buttonStyle(.glass)
        .tint(accentColor)
    }
}

/// A prominent glass action button for primary CTAs (Save, Create, etc.)
struct GlassProminentActionButton: View {
    let title: String
    var systemImage: String? = nil
    var accentColor: Color = .indigo
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.glassProminent)
        .tint(isDisabled ? .gray : accentColor)
        .disabled(isDisabled)
    }
}

// MARK: - Health Ring View

struct HealthRingView: View {
    var progress: Double
    var ringColor: Color = .green
    var backgroundColor: Color?
    var lineWidth: CGFloat = 12

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(
                    backgroundColor ?? (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)),
                    lineWidth: lineWidth
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: min(max(progress, 0.0), 1.0))
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.75), ringColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Tip Glow
            if progress > 0.05 {
                Circle()
                    .fill(ringColor)
                    .frame(width: lineWidth, height: lineWidth)
                    .offset(y: -38)
                    .rotationEffect(.degrees(progress * 360))
                    .shadow(color: ringColor.opacity(0.6), radius: 4, x: 0, y: 0)
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
    }
}

// MARK: - Concentric Activity Rings View

struct ConcentricHealthRingsView: View {
    var outerProgress: Double
    var middleProgress: Double
    var innerProgress: Double

    var body: some View {
        ZStack {
            HealthRingView(
                progress: outerProgress,
                ringColor: .pink,
                lineWidth: 10
            )
            .frame(width: 100, height: 100)

            HealthRingView(
                progress: middleProgress,
                ringColor: .teal,
                lineWidth: 10
            )
            .frame(width: 76, height: 76)

            HealthRingView(
                progress: innerProgress,
                ringColor: .indigo,
                lineWidth: 10
            )
            .frame(width: 52, height: 52)
        }
    }
}

// MARK: - Participant Avatar View

struct ParticipantAvatarView: View {
    let participant: Participant

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor.gradient)
                .frame(width: 38, height: 38)

            Text(initials)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .shadow(color: avatarColor.opacity(0.35), radius: 5, x: 0, y: 2)
        .overlay {
            Circle()
                .glassEffect(.clear, in: .circle)
                .frame(width: 40, height: 40)
        }
    }

    private var initials: String {
        if let fullName = participant.fullName, !fullName.isEmpty {
            let components = fullName.split(separator: " ")
            return components.prefix(2).map { String($0.prefix(1)) }.joined().uppercased()
        }
        return String(participant.handle.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        let index = abs(participant.id.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Previews

#Preview("Top Gradient Wash") {
    ZStack {
        TopGradientWash(tint: .indigo, secondaryTint: .purple)
        VStack {
            Text("Hello, Glass")
                .font(.largeTitle.bold())
            Spacer()
        }
        .padding(.top, 80)
    }
}

#Preview("Health Ring") {
    HealthRingView(progress: 0.72, ringColor: .teal, lineWidth: 12)
        .frame(width: 100, height: 100)
        .padding()
}

#Preview("Concentric Rings") {
    ConcentricHealthRingsView(
        outerProgress: 0.8,
        middleProgress: 0.6,
        innerProgress: 0.9
    )
    .frame(width: 120, height: 120)
    .padding()
}

#Preview("Glass Action Button") {
    VStack(spacing: 16) {
        GlassActionButton(title: "New Group", systemImage: "plus", accentColor: .indigo) {}
        GlassActionButton(title: "Add Expense", systemImage: "plus.circle.fill", accentColor: .teal) {}
        GlassProminentActionButton(title: "Create Group", systemImage: "plus.circle.fill") {}
    }
    .padding()
}
