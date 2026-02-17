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
}

struct PieChart: View {
    let slices: [PieSlice]
    let size: CGFloat

    private var total: Double {
        slices.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        ZStack {
            ForEach(Array(sliceAngles.enumerated()), id: \.element.id) { index, slice in
                PieSliceShape(
                    startAngle: slice.start,
                    endAngle: slice.end
                )
                .fill(slices[index].color)
            }

            // Center circle (donut effect)
            Circle()
                .fill(Theme.Colors.background)
                .frame(width: size * 0.5, height: size * 0.5)
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
        PieSlice(value: 40, color: Theme.Colors.cache, label: "Caches"),
        PieSlice(value: 30, color: Theme.Colors.simulator, label: "Simulators"),
        PieSlice(value: 15, color: Theme.Colors.runtime, label: "Runtimes"),
        PieSlice(value: 10, color: Theme.Colors.build, label: "Builds"),
        PieSlice(value: 5, color: Theme.Colors.deviceSupport, label: "Support")
    ]

    PieChart(slices: slices, size: 150)
        .padding()
        .background(Theme.Colors.background)
}
