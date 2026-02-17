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

    @State private var hoveredSlice: UUID?

    private var total: Double {
        slices.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw slices from largest to smallest angle for proper hit testing
                ForEach(sliceAngles.indices.reversed(), id: \.self) { index in
                    let slice = sliceAngles[index]
                    PieSliceShape(
                        startAngle: slice.start,
                        endAngle: slice.end
                    )
                    .fill(slices[index].color)
                    .scaleEffect(hoveredSlice == slices[index].id ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: hoveredSlice)
                    .contentShape(PieSliceShape(
                        startAngle: slice.start,
                        endAngle: slice.end
                    ))
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredSlice = hovering ? slices[index].id : nil
                        }
                    }
                }

                // Center circle (donut effect)
                Circle()
                    .fill(Theme.Colors.background)
                    .frame(width: size * 0.45, height: size * 0.45)

                // Hover label in center
                if let hoveredId = hoveredSlice,
                   let hovered = slices.first(where: { $0.id == hoveredId }) {
                    VStack(spacing: 2) {
                        Text(hovered.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Colors.primaryText)
                        Text(hovered.size)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }

    private var sliceAngles: [(id: UUID, start: Angle, end: Angle)] {
        var angles: [(id: UUID, start: Angle, end: Angle)] = []
        var currentAngle = Angle.degrees(-90)

        for slice in slices {
            let sliceAngle = total > 0 ? (slice.value / total) * 360 : 0
            let startAngle = currentAngle
            let endAngle = currentAngle + .degrees(sliceAngle)
            angles.append((slice.id, startAngle, endAngle))
            currentAngle = endAngle
        }

        return angles
    }
}

struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
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
