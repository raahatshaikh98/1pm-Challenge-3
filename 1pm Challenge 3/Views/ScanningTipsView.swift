//
//  ScanningTipsView.swift
//  1pm Challenge 3
//

import SwiftUI

/// Shown while the storage scan runs. The app is sandboxed and cannot clear
/// Safari data, other apps' caches or Messages attachments, so this page uses
/// the wait time to point at the places in iOS where those jobs live.
struct ScanningTipsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var tipIndex = 0

    private let tips = StorageTip.all
    private let rotationInterval: Duration = .seconds(4)

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: 108, height: 108)

                SweepingBroom()
            }
            .padding(.bottom, 20)

            VStack(spacing: 7) {
                Text("Sweeping your storage")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .tracking(-0.3)
                    .foregroundStyle(.primary)

                Text("This can take a moment for a large library.")
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .multilineTextAlignment(.center)

            Spacer(minLength: 26)

            tipCard
                .padding(.horizontal, 28)

            tipDots
                .padding(.top, 16)

            Spacer(minLength: 24)

            Text("iOS keeps these areas private.\nYou'll find each one in Settings.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 40)
                .padding(.bottom, 28)
        }
        .task {
            // VoiceOver users can move between tips themselves instead of
            // having the card change underneath the cursor.
            guard !voiceOverEnabled else { return }
            await rotateTips()
        }
    }

    // MARK: - Tip card

    private var tipCard: some View {
        ZStack {
            TipCard(
                tip: tips[tipIndex],
                number: tipIndex + 1,
                total: tips.count
            )
            .id(tipIndex)
            .transition(tipTransition)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: tipIndex)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture(perform: advanceTip)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-tap for the next tip")
    }

    private var tipDots: some View {
        HStack(spacing: 6) {
            ForEach(tips.indices, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        index == tipIndex
                            ? Color.primary.opacity(0.55)
                            : AppTheme.hairline
                    )
                    .frame(width: index == tipIndex ? 16 : 6, height: 6)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: tipIndex)
        .accessibilityHidden(true)
    }

    private var tipTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }

        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 14)),
            removal: .opacity.combined(with: .offset(y: -10))
        )
    }

    // MARK: - Rotation

    private func rotateTips() async {
        guard tips.count > 1 else { return }

        while !Task.isCancelled {
            try? await Task.sleep(for: rotationInterval)
            guard !Task.isCancelled else { return }
            advanceTip()
        }
    }

    private func advanceTip() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
            tipIndex = (tipIndex + 1) % tips.count
        }
    }
}

// MARK: - Tip card

private struct TipCard: View {
    let tip: StorageTip
    let number: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tip.tint.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: tip.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tip.tint)
                }

                Text("TIP \(number) OF \(total)")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.tertiaryText)

                Spacer(minLength: 0)
            }

            Text(tip.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text(tip.detail)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 164, alignment: .topLeading)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(AppTheme.hairline, lineWidth: 0.5)
        }
    }
}

// MARK: - Compact broom animation

/// A smaller version of the landing page's hero broom. It pivots at the top of
/// the handle and lifts a few dust motes, then stops entirely when Reduce
/// Motion is on so nothing moves without the user's consent.
private struct SweepingBroom: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(
            .animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)
        ) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let swing = reduceMotion ? 0 : sin(time * 2 * .pi / 1.2)

            ZStack(alignment: .bottom) {
                if !reduceMotion {
                    dustMotes(time: time)
                        .offset(y: -8)
                }

                BroomIcon()
                    .frame(width: 24, height: 24)
                    .scaleEffect(2.5)
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.primary)
                    .rotationEffect(.degrees(-7 + swing * 14), anchor: .top)
                    .offset(x: swing * 4, y: -7)

                Capsule(style: .continuous)
                    .fill(AppTheme.secondaryText.opacity(0.16))
                    .frame(width: 62, height: 3)
                    .blur(radius: 1.5)
            }
            .frame(width: 92, height: 74)
        }
        .accessibilityHidden(true)
    }

    private func dustMotes(time: TimeInterval) -> some View {
        HStack(spacing: 11) {
            ForEach(0..<3, id: \.self) { index in
                let phase = time * 2.4 + Double(index) * 0.8
                let lift = (sin(phase) + 1) / 2
                let diameter = 3 + CGFloat(index)

                Circle()
                    .fill(AppTheme.secondaryText)
                    .frame(width: diameter, height: diameter)
                    .opacity(0.06 + lift * 0.22)
                    .offset(
                        x: CGFloat(sin(phase * 0.6)) * 6,
                        y: -lift * 8
                    )
            }
        }
    }
}

// MARK: - Tips

private struct StorageTip: Identifiable {
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color

    var id: String { title }

    static let all: [StorageTip] = [
        StorageTip(
            title: "Offload unused apps",
            detail: "Settings › General › iPhone Storage › Offload App frees the app's space while keeping its documents and data.",
            symbolName: "externaldrive.badge.minus",
            tint: AppTheme.dynamic(light: 0x7C5CFC, dark: 0xA78BFA)
        ),
        StorageTip(
            title: "Clear Safari's data",
            detail: "Settings › Safari › Clear History and Website Data removes browsing history and caches this app can't reach.",
            symbolName: "safari",
            tint: AppTheme.dynamic(light: 0x0891B2, dark: 0x22D3EE)
        ),
        StorageTip(
            title: "Empty Recently Deleted",
            detail: "Photos › Albums › Recently Deleted. Deleted photos and videos can stay there for up to 30 days.",
            symbolName: "photo.on.rectangle.angled",
            tint: AppTheme.dynamic(light: 0xD97706, dark: 0xFBBF24)
        ),
        StorageTip(
            title: "Review Messages attachments",
            detail: "Settings › General › iPhone Storage › Messages › Review Large Attachments clears old videos and files.",
            symbolName: "message",
            tint: AppTheme.dynamic(light: 0x10B981, dark: 0x6EE7B7)
        ),
        StorageTip(
            title: "Remove downloaded media",
            detail: "In Music, Podcasts or TV, delete downloads you no longer listen to or watch. Streaming uses far less space.",
            symbolName: "music.note",
            tint: AppTheme.dynamic(light: 0xDB2777, dark: 0xF472B6)
        ),
        StorageTip(
            title: "Clear caches inside each app",
            detail: "Every app owns its sandbox. Caches can only be cleared from that app's own settings, or by offloading it.",
            symbolName: "internaldrive",
            tint: AppTheme.dynamic(light: 0x4F46E5, dark: 0x818CF8)
        )
    ]
}

#Preview {
    ZStack {
        AppBackground()
        ScanningTipsView()
    }
}
