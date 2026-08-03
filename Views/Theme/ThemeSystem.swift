//
//  ThemeSystem.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI

// MARK: - Tab Gradient Preset

enum TabGradientStyle {
    case trips
    case activity
    case settlements
    case settings
    case custom([Color])

    var colors: [Color] {
        switch self {
        case .trips:
            [Color.indigo, Color.purple, Color.blue]
        case .activity:
            [Color.pink, Color.purple, Color.orange]
        case .settlements:
            [Color.teal, Color.emerald, Color.cyan]
        case .settings:
            [Color.cyan, Color.blue, Color.indigo]
        case .custom(let customColors):
            customColors
        }
    }
}

extension Color {
    static let emerald = Color(red: 0.05, green: 0.75, blue: 0.5)
}

// MARK: - Progressive Top Gradient Header Background

struct AmbientMeshBackground: View {
    var style: TabGradientStyle = .trips

    @Environment(\.colorScheme) private var colorScheme
    @State private var animateOffset = false

    var body: some View {
        ZStack {
            // Base background fill: Pure White in Light Mode, Pure Black in Dark Mode
            (colorScheme == .dark ? Color.black : Color(uiColor: .systemBackground))
                .ignoresSafeArea()

            // Full-Width Progressive Top Header Gradient
            GeometryReader { proxy in
                let size = proxy.size
                let headerHeight = size.height * 0.40 // Occupies top ~40% of view

                ZStack(alignment: .top) {
                    // Full-width Gradient Banner
                    LinearGradient(
                        colors: style.colors.map { color in
                            color.opacity(colorScheme == .dark ? 0.55 : 0.28)
                        },
                        startPoint: animateOffset ? .topLeading : .top,
                        endPoint: animateOffset ? .bottomTrailing : .bottom
                    )
                    .frame(width: size.width, height: headerHeight)
                    .blur(radius: 25)

                    // Secondary ambient glow accent moving across top width
                    LinearGradient(
                        colors: [
                            style.colors.first?.opacity(colorScheme == .dark ? 0.35 : 0.2) ?? .clear,
                            style.colors.last?.opacity(colorScheme == .dark ? 0.25 : 0.1) ?? .clear
                        ],
                        startPoint: animateOffset ? .leading : .trailing,
                        endPoint: animateOffset ? .trailing : .leading
                    )
                    .frame(width: size.width, height: headerHeight * 0.8)
                    .blur(radius: 35)
                }
                .mask {
                    // Progressive Fade Mask (100% visible at top, smoothly fades to 0% at bottom)
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.55),
                            .init(color: .black.opacity(0.8), location: 0.75),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: headerHeight)
                }
                .ignoresSafeArea(edges: .top)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                animateOffset.toggle()
            }
        }
    }
}

// MARK: - Apple Card Glass Style Modifier

struct AppleCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 22
    var strokeOpacity: Double = 0.15
    var shadowRadius: CGFloat = 10

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                colorScheme == .dark
                                ? Color.white.opacity(0.04)
                                : Color.white.opacity(0.55)
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        colorScheme == .dark ? .white.opacity(0.22) : .white.opacity(0.9),
                                        colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.06),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: colorScheme == .dark
                        ? Color.black.opacity(0.35)
                        : Color.black.opacity(0.08),
                        radius: shadowRadius,
                        x: 0,
                        y: colorScheme == .dark ? 6 : 4
                    )
            }
    }
}

extension View {
    func appleCardStyle(cornerRadius: CGFloat = 22, strokeOpacity: Double = 0.15, shadowRadius: CGFloat = 10) -> some View {
        modifier(AppleCardStyle(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity, shadowRadius: shadowRadius))
    }

    func clearGlassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(AppleCardStyle(cornerRadius: cornerRadius, strokeOpacity: 0.12, shadowRadius: 6))
    }

    func glassEffect() -> some View {
        modifier(AppleCardStyle(cornerRadius: 16, strokeOpacity: 0.12, shadowRadius: 6))
    }
}

// MARK: - Interactive Clear Glass Button Style

struct AppleCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 16

    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.06))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AppleCardButtonStyle {
    static var appleCard: AppleCardButtonStyle {
        AppleCardButtonStyle()
    }
}

// MARK: - Interactive Glass Action Button Helper

struct GlassActionButton: View {
    let title: String
    let systemImage: String
    var accentColor: Color = .indigo
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(colorScheme == .dark ? .white : accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(accentColor.opacity(colorScheme == .dark ? 0.35 : 0.12))
                    .overlay {
                        Capsule()
                            .stroke(accentColor.opacity(colorScheme == .dark ? 0.55 : 0.3), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.appleCard)
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
            // Outer Ring - Total Spend
            HealthRingView(
                progress: outerProgress,
                ringColor: .pink,
                lineWidth: 10
            )
            .frame(width: 100, height: 100)

            // Middle Ring - Shared Ratio
            HealthRingView(
                progress: middleProgress,
                ringColor: .teal,
                lineWidth: 10
            )
            .frame(width: 76, height: 76)

            // Inner Ring - Settlement Status
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor.gradient)
                .frame(width: 38, height: 38)
            Circle()
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.25) : .white, lineWidth: 1.5)
                .frame(width: 38, height: 38)
            Text(initials)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .shadow(color: avatarColor.opacity(0.35), radius: 5, x: 0, y: 2)
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
