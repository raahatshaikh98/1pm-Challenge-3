//
//  AppTheme.swift
//  1pm Challenge 3
//

import SwiftUI
import UIKit

enum AppTheme {
    static let background = LinearGradient(
        colors: [
            dynamic(light: 0xFFFFFF, dark: 0x0A0A0D),
            dynamic(light: 0xF3F3F7, dark: 0x050506)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let secondaryText = Color.primary.opacity(0.58)
    static let tertiaryText = Color.primary.opacity(0.36)
    static let hairline = Color.primary.opacity(0.08)
    static let surface = Color.primary.opacity(0.055)
    static let chartTrack = Color.primary.opacity(0.055)
    static let accent = Color.primary

    /// A colour that resolves differently in light and dark appearance.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// A calm, near-white or near-black backdrop with the faintest hint of colour depth.
struct AppBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background

            RadialGradient(
                colors: [
                    AppTheme.dynamic(light: 0xA78BFA, dark: 0xA78BFA)
                        .opacity(0.09),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.16),
                startRadius: 8,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
