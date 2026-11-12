//
//  OverviewDonutChartView.swift
//  1pm Challenge 3
//

import SwiftUI
import UIKit

struct OverviewDonutSlice: Identifiable {
    let usage: OverviewUsage
    let startDegrees: Double
    let spanDegrees: Double

    var id: OverviewCategory { usage.category }
    var endDegrees: Double { startDegrees + spanDegrees }
}

/// The overview version of the Home donut. It deliberately shares
/// `DonutChartStyle`, `DonutChartLayout` and `DonutArcShape` with the Home
/// chart, so the ring geometry and animation stay identical.
struct OverviewDonutChartView: View {
    let kind: StorageCategory
    let usages: [OverviewUsage]
    let totalBytes: Int64
    let filterSummary: String
    let diameter: CGFloat
    let onSelectCategory: (OverviewCategory) -> Void

    @State private var reveal: Double = 0
    @State private var hasAnimated = false
    @State private var selectedCategory: OverviewCategory?
    @State private var lastNavigation = Date.distantPast

    private let style = DonutChartStyle()

    /// A single category fills the entire ring, so the usual gap would only
    /// expose the grey track behind it for no reason.
    private var gapDegrees: Double {
        usages.count <= 1 ? 0 : style.segmentGapDegrees
    }

    private var slices: [OverviewDonutSlice] {
        let gap = gapDegrees
        let spans = DonutChartLayout.spans(
            for: usages.map(\.bytes),
            gapDegrees: gap
        )
        guard spans.count == usages.count else { return [] }

        var cursor = -90 + gap / 2

        return usages.indices.map { index in
            let slice = OverviewDonutSlice(
                usage: usages[index],
                startDegrees: cursor,
                spanDegrees: spans[index]
            )
            cursor += spans[index] + gap
            return slice
        }
    }

    private var dataSignature: String {
        usages
            .map { "\($0.category.rawValue):\($0.bytes)" }
            .joined(separator: "|")
    }

    var body: some View {
        ZStack {
            if usages.count > 1 {
                Circle()
                    .stroke(AppTheme.chartTrack, lineWidth: style.ringWidth)
                    .padding(style.ringWidth / 2)
            }

            ForEach(slices) { slice in
                DonutArcShape(
                    startAngle: .degrees(slice.startDegrees),
                    endAngle: .degrees(visibleEnd(for: slice)),
                    ringWidth: style.ringWidth
                )
                .stroke(
                    slice.usage.category.color,
                    style: StrokeStyle(lineWidth: style.ringWidth, lineCap: .butt)
                )
                .opacity(segmentOpacity(for: slice.usage.category))
                .shadow(
                    color: selectedCategory == slice.usage.category
                        ? slice.usage.category.color.opacity(0.35)
                        : .clear,
                    radius: 12
                )
            }

            centreLabel
                .allowsHitTesting(false)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .onTapGesture(coordinateSpace: .local) { location in
            handleTap(at: location)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title) storage overview")
        .accessibilityValue(accessibilitySummary)
        .accessibilityAddTraits(.isImage)
        .onAppear {
            selectedCategory = nil
            animateInIfNeeded(force: false)
        }
        .onChange(of: dataSignature) { _, _ in
            selectedCategory = nil
            animateInIfNeeded(force: true)
        }
    }

    // MARK: - Centre

    private var centreLabel: some View {
        VStack(spacing: 3) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(kind.color)
                .padding(.bottom, 3)

            Text(StorageFormatter.headline(totalBytes))
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .tracking(-1.2)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text("\(kind.title) storage")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            Text(filterSummary)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .padding(.horizontal, style.ringWidth + 10)
        .frame(width: diameter - style.ringWidth * 2 - 20)
    }

    private var accessibilitySummary: String {
        guard !usages.isEmpty else { return "No categories shown" }
        return usages
            .map { "\($0.category.title) \($0.formattedSize)" }
            .joined(separator: ", ")
    }

    // MARK: - Reveal animation

    private func visibleEnd(for slice: OverviewDonutSlice) -> Double {
        let sweep = -90 + 360 * reveal
        return min(slice.endDegrees, max(slice.startDegrees, sweep))
    }

    private func animateInIfNeeded(force: Bool) {
        guard force || !hasAnimated else { return }
        guard !slices.isEmpty else {
            reveal = 0
            return
        }

        hasAnimated = true

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            reveal = 0
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: style.animationDuration)) {
                reveal = 1
            }
        }
    }

    // MARK: - Interaction

    private func segmentOpacity(for category: OverviewCategory) -> Double {
        guard let selectedCategory else { return 1 }
        return selectedCategory == category ? 1 : 0.3
    }

    private func handleTap(at location: CGPoint) {
        guard let category = category(at: location) else { return }

        let now = Date()
        guard now.timeIntervalSince(lastNavigation) > 0.35 else { return }
        lastNavigation = now

        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        feedback.impactOccurred()

        withAnimation(.easeOut(duration: 0.18)) {
            selectedCategory = category
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onSelectCategory(category)
        }
    }

    private func category(at location: CGPoint) -> OverviewCategory? {
        let centre = CGPoint(x: diameter / 2, y: diameter / 2)
        let dx = location.x - centre.x
        let dy = location.y - centre.y
        let distance = sqrt(dx * dx + dy * dy)

        let outerRadius = diameter / 2
        let innerRadius = outerRadius - style.ringWidth
        let hitSlop: CGFloat = 10
        guard distance >= innerRadius - hitSlop,
              distance <= outerRadius + hitSlop else {
            return nil
        }

        var angle = atan2(Double(dy), Double(dx)) * 180 / Double.pi
        if angle < 0 { angle += 360 }

        for slice in slices {
            var start = slice.startDegrees.truncatingRemainder(dividingBy: 360)
            if start < 0 { start += 360 }

            let relative = (angle - start + 360).truncatingRemainder(dividingBy: 360)
            if relative <= slice.spanDegrees {
                return slice.usage.category
            }
        }

        return nil
    }
}
