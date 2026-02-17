//
//  GlassyCard.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import SwiftUI

struct GlassyCard<Content: View>: View {
    let content: Content
    let action: (() -> Void)?
    
    @State private var isHovering = false
    
    init(action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Glass Background
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                .fill(Theme.Colors.cardBackground)
            
            // Border (simulating edge light)
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            
            content
                .padding()
        }
        .scaleEffect(isHovering && action != nil ? 1.02 : 1.0)
        .opacity(isHovering && action != nil ? 1.0 : 0.9)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hover in
            isHovering = hover
        }
        .onTapGesture {
            if let action = action {
                action()
            }
        }
    }
}
