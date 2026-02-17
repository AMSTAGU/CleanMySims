//
//  ProgressBar.swift
//  CleanMySims
//

import SwiftUI

struct ProgressBar: View {
    let progress: Double // 0.0 to 1.0
    let isIndeterminate: Bool
    let color: Color

    @State private var animatedProgress: CGFloat = 0
    @State private var fakeProgress: CGFloat = 0

    init(progress: Double = 0, isIndeterminate: Bool = false, color: Color? = nil) {
        self.progress = progress
        self.isIndeterminate = isIndeterminate
        self.color = color ?? Theme.Colors.secondaryText.opacity(0.6)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.border)

                // Progress fill
                if isIndeterminate {
                    // Fake progress - fills from 0% to 90% progressively
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * fakeProgress)
                        .onAppear {
                            // Animate to 90% over 3 seconds
                            withAnimation(.easeInOut(duration: 3.0)) {
                                fakeProgress = 0.9
                            }
                        }
                } else {
                    // Determinate progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
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
