//
//  DonutChartView.swift
//  1pm Challenge 3
//

import SwiftUI
import UIKit

/// All donut geometry lives here so the gap, ring thickness and animation can
/// be adjusted in one place without touching the drawing code.
struct DonutChartStyle {
    var ringWidth: CGFloat = 34
    /// Visual gap between segment ends, in degrees. Equal for every pair.
    /// Deliberately small so the ring reads as one continuous shape.
    var segmentGapDegrees: Double = 0.8
    var animationDuration: Double = 1.05
}

struct DonutSegment: Identifiable {
    let usage: CategoryUsage
    let startDegrees: Double
    let spanDegrees: Double

    var id: StorageCategory { usage.category }
    var endDegrees: Double { startDegrees + spanDegrees }
}

enum DonutChartLayout {
    /// Segments are proportional to the measured category values. The gaps are
    /// subtracted from the drawable circle first, so as values change the
    /// segments keep their real proportions and the gaps stay uniform.
    ///
    /// Every measurable category keeps a small minimum span. That way an empty
    /// Files folder (0 bytes) is still visible and tappable on the ring instead
    /// of silently disappearing.
    static func segments(
        for usages: [CategoryUsage],
        gapDegrees: Double,
        minimumSpanDegrees: Double = 4
    ) -> [DonutSegment] {
        let active = usages.filter { $0.quality != .unavailable }
        let spans = spans(
            for: active.map(\.bytes),
            gapDegrees: gapDegrees,
            minimumSpanDegrees: minimumSpanDegrees
        )
        guard !spans.isEmpty else { return [] }

        let gap = max(0, gapDegrees)
        var cursor = -90 + gap / 2

        return active.indices.map { index in
            let segment = DonutSegment(
                usage: active[index],
                startDegrees: cursor,
                spanDegrees: spans[index]
            )
            cursor += spans[index] + gap
            return segment
        }
    }

    /// Shared water-filling layout used by the Home chart and the overview
    /// charts. The smallest categories are clamped to the minimum span first,
    /// then the remaining degrees are shared by byte size.
    static func spans(
        for byteValues: [Int64],
        gapDegrees: Double,
        minimumSpanDegrees: Double = 4
    ) -> [Double] {
        let total = byteValues.reduce(Int64(0), +)
        guard !byteValues.isEmpty, total > 0 else { return [] }

        let gap = max(0, gapDegrees)
        let drawableDegrees = max(0, 360 - gap * Double(byteValues.count))
        guard drawableDegrees > 0 else {
            return [Double](repeating: 0, count: byteValues.count)
        }
        let minimum = min(
            max(0, minimumSpanDegrees),
            drawableDegrees / Double(byteValues.count)
        )

        var spans = [Double](repeating: 0, count: byteValues.count)
        var remainingDegrees = drawableDegrees
        var remainingBytes = Double(total)

        let smallestFirst = byteValues.indices.sorted {
            byteValues[$0] < byteValues[$1]
        }

        for (position, index) in smallestFirst.enumerated() {
            let slotsLeft = Double(byteValues.count - position)
            let natural = remainingBytes > 0
                ? remainingDegrees * (Double(byteValues[index]) / remainingBytes)
                : remainingDegrees / slotsLeft
            let span = natural < minimum ? minimum : natural
            spans[index] = span
            remainingDegrees -= span
            remainingBytes -= Double(byteValues[index])
        }

        return spans
    }
}

struct DonutArcShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var ringWidth: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = .degrees(newValue.first)
            endAngle = .degrees(newValue.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        guard endAngle.degrees > startAngle.degrees + 0.001 else { return Path() }

        let radius = min(rect.width, rect.height) / 2 - ringWidth / 2
        guard radius > 0 else { return Path() }

        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

struct DonutChartView: View {
    let snapshot: StorageSnapshot
    let diameter: CGFloat
    let onSelectCategory: (StorageCategory) -> Void

    @State private var reveal: Double = 0
    @State private var hasAnimated = false
    @State private var selectedCategory: StorageCategory?
    @State private var lastNavigation = Date.distantPast

    private let style = DonutChartStyle()

    private var segments: [DonutSegment] {
        DonutChartLayout.segments(
            for: snapshot.categories,
            gapDegrees: style.segmentGapDegrees
        )
    }

    private var dataSignature: String {
        let values = snapshot.categories.map {
            "\($0.category.rawValue):\($0.bytes):\($0.quality.rawValue)"
        }
        return "\(snapshot.isLoaded)|\(values.joined(separator: ","))"
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.chartTrack, lineWidth: style.ringWidth)
                .padding(style.ringWidth / 2)

            ForEach(segments) { segment in
                DonutArcShape(
                    startAngle: .degrees(segment.startDegrees),
                    endAngle: .degrees(visibleEnd(for: segment)),
                    ringWidth: style.ringWidth
                )
                .stroke(
                    segment.usage.category.color,
                    style: StrokeStyle(lineWidth: style.ringWidth, lineCap: .butt)
                )
                .opacity(segmentOpacity(for: segment.usage.category))
                .shadow(
                    color: selectedCategory == segment.usage.category
                        ? segment.usage.category.color.opacity(0.35)
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
        .accessibilityLabel("Storage distribution")
        .accessibilityValue(snapshot.accessibilitySummary)
        .accessibilityAddTraits(.isImage)
        .accessibilityAction(named: Text("Open Photos")) {
            onSelectCategory(.photos)
        }
        .accessibilityAction(named: Text("Open Videos")) {
            onSelectCategory(.videos)
        }
        .accessibilityAction(named: Text("Open Files")) {
            onSelectCategory(.files)
        }
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
        VStack(spacing: 4) {
            Text(usedText)
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .tracking(-1.4)
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(capacityText)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            Text(statusText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 27, alignment: .top)
                .padding(.top, 2)
        }
        .padding(.horizontal, style.ringWidth + 12)
    }

    private var usedText: String {
        guard snapshot.isLoaded, let used = snapshot.usedCapacity else { return "—" }
        guard let total = snapshot.totalCapacity else {
            return StorageFormatter.headline(used)
        }
        return StorageFormatter.usedHeadline(used, total: total)
    }

    private var capacityText: String {
        guard snapshot.isLoaded else { return "Measuring storage…" }
        guard let total = snapshot.totalCapacity else { return "Storage unavailable" }
        guard snapshot.usedCapacity != nil else {
            return "\(StorageFormatter.headline(total)) capacity"
        }
        return "of \(StorageFormatter.headline(total)) used"
    }

    private var statusText: String {
        guard snapshot.isLoaded else { return "" }

        if let selectedCategory {
            let usage = snapshot.usage(for: selectedCategory)
            let suffix = usage.quality == .estimated ? " · estimated" : ""
            return "\(selectedCategory.title) · \(usage.formattedSize)\(suffix)"
        }

        return snapshot.statusCaption
    }

    private var statusColor: Color {
        guard let selectedCategory else { return AppTheme.secondaryText }
        return selectedCategory.color.opacity(0.9)
    }

    // MARK: - Reveal animation

    private func visibleEnd(for segment: DonutSegment) -> Double {
        let sweep = -90 + 360 * reveal
        return min(segment.endDegrees, max(segment.startDegrees, sweep))
    }

    private func animateInIfNeeded(force: Bool) {
        guard force || !hasAnimated else { return }
        guard !segments.isEmpty else {
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

    private func segmentOpacity(for category: StorageCategory) -> Double {
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

        // A short beat of visual feedback before the push.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onSelectCategory(category)
        }
    }

    /// Converts a tap into a category only when it lands on that segment's
    /// arc and radial band. Taps in the gaps or hollow centre are ignored.
    private func category(at location: CGPoint) -> StorageCategory? {
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

        for segment in segments {
            var start = segment.startDegrees.truncatingRemainder(dividingBy: 360)
            if start < 0 { start += 360 }

            let relative = (angle - start + 360).truncatingRemainder(dividingBy: 360)
            if relative <= segment.spanDegrees {
                return segment.usage.category
            }
        }

        return nil
    }
}
