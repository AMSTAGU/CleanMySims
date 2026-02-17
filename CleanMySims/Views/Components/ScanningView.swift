//
//  ScanningView.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import SwiftUI

struct ScanningView: View {
    var title: String = "Scanning Simulators..."
    var icon: String = "magnifyingglass"
    var rotateIcon: Bool = true
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Dark Overlay
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            // Pulsing Circles
            ForEach(0..<4) { index in
                Circle()
                    .stroke(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                    .scaleEffect(isAnimating ? 2.5 : 0.5)
                    .opacity(isAnimating ? 0.0 : 0.5)
                    .animation(
                        Animation.easeOut(duration: 2.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5),
                        value: isAnimating
                    )
            }
            .frame(width: 150, height: 150)
            
            // Center Icon
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.8), radius: 10, x: 0, y: 0)
                .rotationEffect(.degrees(rotateIcon && isAnimating ? 360 : 0))
                .scaleEffect(rotateIcon ? 1.0 : (isAnimating ? 1.1 : 0.9)) // Pulse if not rotating
                .animation(
                    rotateIcon
                    ? Animation.linear(duration: 4).repeatForever(autoreverses: false)
                    : Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Text(title)
                .font(Theme.Fonts.headline)
                .foregroundStyle(.white)
                .padding(.top, 200)
        }
        .onAppear {
            isAnimating = true
        }
    }
}
