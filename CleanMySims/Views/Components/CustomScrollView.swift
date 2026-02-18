//
//  CustomScrollView.swift
//  CleanMySims
//

import SwiftUI

struct CustomScrollView<Content: View>: View {
    let content: Content
    
    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var isHovering = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                ScrollView(showsIndicators: false) {
                    content
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: proxy.frame(in: .named("scroll")).origin.y
                                    )
                                    .preference(
                                        key: ContentHeightPreferenceKey.self,
                                        value: proxy.size.height
                                    )
                            }
                        )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                .onPreferenceChange(ContentHeightPreferenceKey.self) { value in
                    contentHeight = value
                }
                .onAppear {
                    viewportHeight = geometry.size.height
                }
                .onChange(of: geometry.size.height) { _, newValue in
                    viewportHeight = newValue
                }
                .onHover { hovering in
                    isHovering = hovering
                }
                
                // Custom Scrollbar
                if contentHeight > viewportHeight {
                    let indicatorHeight = max(30, viewportHeight * (viewportHeight / contentHeight))
                    let scrollPercentage = -scrollOffset / (contentHeight - viewportHeight)
                    let indicatorOffset = scrollPercentage * (viewportHeight - indicatorHeight)
                    
                    // Clamping offset to stay within bounds
                    let clampedOffset = max(0, min(viewportHeight - indicatorHeight, indicatorOffset))
                    
                    ZStack {
                        Capsule()
                            .fill(Color.black.opacity(isHovering ? 0.5 : 0.3)) // Increased opacity
                            .frame(width: 6, height: indicatorHeight)
                            .padding(.trailing, 4)
                            .offset(y: clampedOffset)
                            .animation(.easeOut(duration: 0.1), value: isHovering)
                    }
                    .frame(width: 14, height: viewportHeight, alignment: .topTrailing)
                    .background(Color.white.opacity(0.001)) // Catch hover events on the track
                    .onHover { hovering in
                        isHovering = hovering
                    }
                }
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
