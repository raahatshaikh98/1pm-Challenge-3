//
//  CategoryDetailView.swift
//  1pm Challenge 3
//

import SwiftUI
import UIKit

struct CategoryDetailView: View {
    let usage: CategoryUsage
    var onAddFiles: (() -> Void)?

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                VStack(spacing: 16) {
                    icon

                    Text(usage.formattedSize)
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .tracking(-1)
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    qualityBadge

                    Text(explanation)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 280)

                    if usage.quality == .unavailable,
                       usage.category == .photos || usage.category == .videos {
                        settingsButton
                            .padding(.top, 2)
                    }

                    if let onAddFiles, usage.category == .files {
                        addFilesButton(action: onAddFiles)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 24)

                Text(footerText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 28)
        }
        .navigationTitle(usage.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(usage.category.color.opacity(0.12))
                .frame(width: 92, height: 92)

            Circle()
                .stroke(usage.category.color.opacity(0.2), lineWidth: 1)
                .frame(width: 92, height: 92)

            Image(systemName: usage.category.symbolName)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(usage.category.color)
        }
    }

    private var qualityBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: badgeSymbol)
                .font(.system(size: 10, weight: .semibold))

            Text(badgeText)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.primary.opacity(0.62))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.surface)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badgeText)
    }

    private var badgeSymbol: String {
        switch usage.quality {
        case .verified:
            return "checkmark.seal.fill"
        case .estimated:
            return "exclamationmark.circle.fill"
        case .unavailable:
            return "lock.fill"
        }
    }

    private var badgeText: String {
        switch usage.quality {
        case .verified:
            return "Measured"
        case .estimated:
            return "Estimated"
        case .unavailable:
            return "Unavailable"
        }
    }

    private var explanation: String {
        if let note = usage.note {
            return note
        }

        switch usage.quality {
        case .verified:
            if usage.category == .files {
                return "Measured from files in On My iPhone › 1pm Challenge 3."
            }
            return "Measured from the \(usage.category.title.lowercased()) on this iPhone."
        case .estimated:
            return "This value is an estimate based on the items this app can access."
        case .unavailable:
            return "This category cannot be measured right now."
        }
    }

    private var footerText: String {
        if usage.category == .files {
            return "Files stay in On My iPhone › 1pm Challenge 3."
        }
        return "Detailed \(usage.category.title.lowercased()) tools are coming soon."
    }

    private var settingsButton: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 6) {
                Text("Open Settings")
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(uiColor: .systemBackground))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary)
            )
        }
        .buttonStyle(.plain)
    }

    private func addFilesButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add files from On My iPhone")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(uiColor: .systemBackground))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary)
            )
        }
        .buttonStyle(.plain)
    }
}
