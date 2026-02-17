//
//  ProgressBar.swift
//  CleanMySims
//

import SwiftUI

struct ProgressBar: View {
    let progress: Double // 0.0 to 1.0
    let isIndeterminate: Bool
    let gradientColors: [Color]

    @State private var animatedProgress: CGFloat = 0
    @State private var indeterminateOffset: CGFloat = 0

    init(progress: Double = 0, isIndeterminate: Bool = false, gradientColors: [Color]? = nil) {
        self.progress = progress
        self.isIndeterminate = isIndeterminate
        self.gradientColors = gradientColors ?? [
            Theme.Colors.cache,
            Theme.Colors.simulator,
            Theme.Colors.runtime,
            Theme.Colors.build,
            Theme.Colors.deviceSupport
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.border)

                // Progress fill
                if isIndeterminate {
                    // Indeterminate animation
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.3)
                        .offset(x: indeterminateOffset)
                        .onAppear {
                            withAnimation(
                                .linear(duration: 1)
                                .repeatForever(autoreverses: false)
                            ) {
                                indeterminateOffset = geometry.size.width * 0.7
                            }
                        }
                } else {
                    // Determinate progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * animatedProgress)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                animatedProgress = progress
                            }
                        }
                        .onChange(of: progress) { _, newValue in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                animatedProgress = newValue
                            }
                        }
                }
            }
        }
        .frame(height: 4)
    }
}

#Preview("Determinate") {
    ProgressBar(progress: 0.6)
        .padding()
}

#Preview("Indeterminate") {
    ProgressBar(isIndeterminate: true)
        .padding()
}
