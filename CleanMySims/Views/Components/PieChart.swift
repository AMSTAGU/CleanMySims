//
//  PieChart.swift
//  CleanMySims
//

import SwiftUI

struct PieSlice: Identifiable {
    let id = UUID()
    let value: Double
    let color: Color
    let label: String
    let size: String
}

struct PieChart: View {
    let slices: [PieSlice]
    let size: CGFloat

    @State private var hoveredSlice: Int?

    // Find the index of the largest slice to select by default
    private var largestSliceIndex: Int? {
        slices.indices.max(by: { slices[$0].value < slices[$1].value })
    }

    // Active slice is either the hovered one or the largest one by default
    private var activeSliceIndex: Int? {
        hoveredSlice ?? largestSliceIndex
    }

    private var total: Double {
        slices.reduce(0) { $0 + $1.value }
    }

    private func sliceIndex(at point: CGPoint, in frame: CGRect) -> Int? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let radius = min(frame.width, frame.height) / 2
        let innerRadius = radius * 0.55 // Match the shape's inner radius ratio

        // Check if point is inside the donut ring
        if distance > radius || distance < innerRadius {
            return nil
        }

        var angle = atan2(dy, dx) * 180 / .pi
        angle = angle + 90
        if angle < 0 { angle += 360 }

        var currentAngle = 0.0
        for (index, slice) in slices.enumerated() {
            let sliceAngle = total > 0 ? (slice.value / total) * 360 : 0
            if angle >= currentAngle && angle < currentAngle + sliceAngle {
                return index
            }
            currentAngle += sliceAngle
        }

        return nil
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw all slices
                ForEach(sliceAngles.indices, id: \.self) { index in
                    let slice = sliceAngles[index]
                    PieSliceShape(
                        startAngle: slice.start,
                        endAngle: slice.end,
                        innerRadiusRatio: 0.55 // Define donut hole size
                    )
                    .fill(slices[index].color)
                    .scaleEffect(activeSliceIndex == index ? 1.05 : 1.0) // Subtle scale for selection
                    .animation(.easeInOut(duration: 0.2), value: activeSliceIndex)
                }

                // Hover label in center (no background, so transparent)
                if let index = activeSliceIndex {
                    VStack(spacing: 2) {
                        Text(slices[index].label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Colors.primaryText)
                        Text(slices[index].size)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle()) // Ensure hit testing works on the whole area
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredSlice = sliceIndex(at: location, in: geometry.frame(in: .local))
                case .ended:
                    hoveredSlice = nil
                }
            }
        }
        .frame(width: size, height: size)
    }

    private var sliceAngles: [(start: Angle, end: Angle)] {
        var angles: [(start: Angle, end: Angle)] = []
        var currentAngle = Angle.degrees(-90)

        for _ in slices {
            let sliceAngle = total > 0 ? (slices[angles.count].value / total) * 360 : 0
            let startAngle = currentAngle
            let endAngle = currentAngle + .degrees(sliceAngle)
            angles.append((startAngle, endAngle))
            currentAngle = endAngle
        }

        return angles
    }
}

struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    var innerRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRadiusRatio

        // Draw the donut wedge
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true // Reverse direction for inner arc to close the shape correctly
        )
        
        path.closeSubpath()

        return path
    }
}

#Preview {
    let slices = [
        PieSlice(value: 40, color: Theme.Colors.cache, label: "Caches", size: "4.2 GB"),
        PieSlice(value: 30, color: Theme.Colors.simulator, label: "Simulators", size: "3.1 GB"),
        PieSlice(value: 15, color: Theme.Colors.runtime, label: "Runtimes", size: "1.5 GB"),
        PieSlice(value: 10, color: Theme.Colors.build, label: "Builds", size: "1.0 GB"),
        PieSlice(value: 5, color: Theme.Colors.deviceSupport, label: "Support", size: "0.5 GB")
    ]

    PieChart(slices: slices, size: 180)
        .padding()
        .background(Theme.Colors.background)
}
