//
//  ScanLandingView.swift
//  1pm Challenge 3
//

import SwiftUI
import UIKit

/// The app's starting page. The user taps SCAN, the broom sweeps while the
/// storage totals are measured, and the button turns into a light-green DONE
/// before the caller replaces this screen with the donut Home page.
struct ScanLandingView: View {
    var onScan: () async -> Void
    var onFinished: () -> Void

    @State private var phase: ScanPhase = .idle

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                BroomHero(isSweeping: phase == .scanning)
                    .padding(.bottom, 24)

                Text("Clean up your storage")
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("See what's taking up space on your iPhone.")
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 9)
                    .padding(.horizontal, 40)

                Spacer(minLength: 28)

                scanButton

                Text(footnote)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 44)
                    .padding(.top, 16)
                    .padding(.bottom, 26)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Scan button

    private var scanButton: some View {
        Button(action: startScan) {
            Text(buttonTitle)
                .font(.system(size: 15, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(buttonForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    Capsule(style: .continuous)
                        .fill(buttonBackground)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(buttonBorder, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .disabled(phase != .idle)
        .padding(.horizontal, 44)
        .accessibilityLabel(accessibilityLabel)
    }

    private var buttonTitle: String {
        switch phase {
        case .idle:
            return "SCAN"
        case .scanning:
            return "SCANNING"
        case .done:
            return "DONE"
        }
    }

    private var buttonBackground: Color {
        switch phase {
        case .idle:
            return .primary
        case .scanning:
            return AppTheme.surface
        case .done:
            return successColor.opacity(0.16)
        }
    }

    private var buttonForeground: Color {
        switch phase {
        case .idle:
            return Color(uiColor: .systemBackground)
        case .scanning:
            return AppTheme.secondaryText
        case .done:
            return successColor
        }
    }

    private var buttonBorder: Color {
        phase == .done ? successColor.opacity(0.35) : .clear
    }

    private var successColor: Color {
        AppTheme.dynamic(light: 0x10B981, dark: 0x6EE7B7)
    }

    private var footnote: String {
        switch phase {
        case .idle:
            return "Only the photos, videos and files you allow are measured.\nNothing leaves this iPhone."
        case .scanning:
            return "Sweeping your storage…"
        case .done:
            return "Your storage breakdown is ready."
        }
    }

    private var accessibilityLabel: String {
        switch phase {
        case .idle:
            return "Scan storage"
        case .scanning:
            return "Scanning storage"
        case .done:
            return "Scan complete"
        }
    }

    // MARK: - Actions

    @MainActor
    private func startScan() {
        guard phase == .idle else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .scanning
        }

        Task {
            let started = Date()
            await onScan()

            // Keep the sweep visible for a moment on small libraries so the
            // transition never flashes straight from SCAN to DONE.
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < 1.5 {
                try? await Task.sleep(for: .seconds(1.5 - elapsed))
            }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                phase = .done
            }

            // Hold the light-green DONE state long enough to register before
            // the root is replaced by the donut Home page.
            try? await Task.sleep(for: .milliseconds(900))

            onFinished()
        }
    }
}

private enum ScanPhase {
    case idle
    case scanning
    case done
}

// MARK: - Broom hero

/// Scales the shared tab-bar broom into a hero illustration. While scanning,
/// the broom pivots at the handle and small dust motes drift below the bristles.
/// The timeline pauses when idle, so no work is done outside an active scan.
private struct BroomHero: View {
    let isSweeping: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAnimating: Bool {
        isSweeping && !reduceMotion
    }

    var body: some View {
        TimelineView(
            .animation(minimumInterval: 1.0 / 30.0, paused: !isAnimating)
        ) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let swing = isAnimating ? sin(time * 2 * .pi / 1.5) : 0

            ZStack {
                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: 216, height: 216)

                if isAnimating {
                    dustMotes(time: time)
                        .offset(y: 76)
                }

                BroomIcon()
                    .frame(width: 24, height: 24)
                    .scaleEffect(7)
                    .frame(width: 200, height: 200)
                    .foregroundStyle(.primary)
                    .rotationEffect(.degrees(-6 + swing * 14), anchor: .top)
                    .offset(y: 2)
            }
            .frame(width: 232, height: 232)
        }
        .accessibilityHidden(true)
    }

    private func dustMotes(time: TimeInterval) -> some View {
        HStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { index in
                let phase = time * 2.2 + Double(index) * 0.9
                let lift = (sin(phase) + 1) / 2
                let diameter = 7 + CGFloat(index) * 3

                Circle()
                    .fill(AppTheme.secondaryText)
                    .frame(width: diameter, height: diameter)
                    .opacity(0.05 + lift * 0.28)
                    .offset(
                        x: CGFloat(sin(phase * 0.7)) * 10,
                        y: -lift * 16
                    )
            }
        }
        .frame(width: 120, height: 30)
    }
}

#Preview {
    ScanLandingView(
        onScan: {},
        onFinished: {}
    )
}
