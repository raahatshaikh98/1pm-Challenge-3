//
//  BroomIcon.swift
//  1pm Challenge 3
//

import SwiftUI

/// SF Symbols has no broom glyph, so this small vector is shared by the tab bar
/// and the scan landing page. It draws in a 24 x 24 design space and scales
/// cleanly to any size without an asset dependency.
struct BroomIcon: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 12, y: 2.6))
                path.addLine(to: CGPoint(x: 12, y: 11.4))
            }
            .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            Path { path in
                path.move(to: CGPoint(x: 7.9, y: 11.0))
                path.addLine(to: CGPoint(x: 16.1, y: 11.0))
                path.addLine(to: CGPoint(x: 18.3, y: 18.6))
                path.addQuadCurve(
                    to: CGPoint(x: 17.1, y: 19.9),
                    control: CGPoint(x: 18.3, y: 19.9)
                )
                path.addLine(to: CGPoint(x: 6.9, y: 19.9))
                path.addQuadCurve(
                    to: CGPoint(x: 5.7, y: 18.6),
                    control: CGPoint(x: 5.7, y: 19.9)
                )
                path.closeSubpath()
            }
            .fill()

            Path { path in
                let starts: [CGFloat] = [7.3, 10.1, 13.9, 16.7]
                let ends: [CGFloat] = [6.8, 9.7, 14.3, 17.2]
                for index in starts.indices {
                    path.move(to: CGPoint(x: starts[index], y: 19.4))
                    path.addLine(to: CGPoint(x: ends[index], y: 21.5))
                }
            }
            .stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        .frame(width: 24, height: 24)
    }
}
