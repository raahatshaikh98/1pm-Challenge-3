//
//  StorageCapacityBar.swift
//  1pm Challenge 3
//

import SwiftUI

/// A thin horizontal bar under the donut. The filled part is used space and
/// the remaining grey track is the space still available on the device. Both
/// values come from the real volume capacity reported by iOS.
struct StorageCapacityBar: View {
    let used: Int64?
    let total: Int64?

    private var usedFraction: Double {
        guard let used, let total, total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }

    private var availableText: String {
        guard let used, let total else { return "—" }
        return StorageFormatter.headline(max(0, total - used))
    }

    private var usedText: String {
        guard let used else { return "—" }
        return StorageFormatter.headline(used) + " used"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Available")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                Spacer(minLength: 8)

                Text(availableText)
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(AppTheme.dynamic(light: 0xE3E3E8, dark: 0x2A2A2E))

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.primary.opacity(0.86), Color.primary.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * usedFraction)
                }
            }
            .frame(height: 9)
        }
        .animation(.easeInOut(duration: 0.9), value: usedFraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storage availability")
        .accessibilityValue("\(usedText), \(availableText) available")
    }
}
