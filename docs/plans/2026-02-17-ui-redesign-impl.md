# CleanMySims UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refaire complètement l'UI de CleanMySims avec un design "Zen Minimal" - flat design épuré, couleurs pastel, fenêtre immersive.

**Architecture:** On garde la structure MVVM existante mais on remplace tous les composants visuels. Nouveaux composants réutilisables (MinimalCard, HelpIcon, ProgressBar, ConfirmDialog). Theme.swift entièrement refait.

**Tech Stack:** SwiftUI, macOS 14+, SF Pro fonts

**Design Reference:** `docs/plans/2026-02-17-ui-redesign-design.md`

---

## Task 1: Nouveau système de Theme (couleurs & typo)

**Files:**
- Modify: `CleanMySims/Views/Theme.swift` (remplacer tout)

**Step 1: Réécrire Theme.swift avec la nouvelle palette**

Remplacer tout le contenu de `Theme.swift` par :

```swift
//
//  Theme.swift
//  CleanMySims
//

import SwiftUI

struct Theme {
    struct Colors {
        // Base colors
        static let background = Color(hex: "FAFAFA")
        static let sidebarBackground = Color(hex: "F5F5F5")
        static let primaryText = Color(hex: "2D2D2D")
        static let secondaryText = Color(hex: "6B6B6B")
        static let border = Color(hex: "E5E5E5")
        static let hoverBackground = Color(hex: "EEEEEE")

        // Category accent colors (pastel)
        static let cache = Color(hex: "A8D8EA")        // Sky blue
        static let simulator = Color(hex: "F8B4B4")    // Powder pink
        static let runtime = Color(hex: "B5EAD7")      // Mint
        static let build = Color(hex: "FFDAC1")        // Peach
        static let deviceSupport = Color(hex: "C7CEEA") // Lavender

        // Semantic colors
        static let danger = Color(hex: "E88B8B")       // Soft coral
        static let success = Color(hex: "A8D5BA")      // Sage green

        // Helper to get color by type
        static func color(for type: CleanableItemType) -> Color {
            switch type {
            case .cache: return cache
            case .virtualDevice: return simulator
            case .runtimes: return runtime
            case .builds: return build
            case .deviceSupport: return deviceSupport
            }
        }
    }

    struct Fonts {
        static let title = Font.system(size: 32, weight: .light)
        static let headline = Font.system(size: 16, weight: .medium)
        static let subheadline = Font.system(size: 15, weight: .medium)
        static let body = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 11, weight: .regular)
        static let mono = Font.system(size: 11, weight: .regular, design: .monospaced)
    }

    struct Layout {
        static let windowWidth: CGFloat = 800
        static let windowHeight: CGFloat = 550
        static let sidebarWidth: CGFloat = 200
        static let cardCornerRadius: CGFloat = 12
        static let buttonCornerRadius: CGFloat = 8
        static let padding: CGFloat = 16
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

**Step 2: Commit**

```bash
git add CleanMySims/Views/Theme.swift
git commit -m "feat(theme): new Zen Minimal color palette and typography"
```

---

## Task 2: Composant HelpIcon (tooltips d'aide)

**Files:**
- Create: `CleanMySims/Views/Components/HelpIcon.swift`

**Step 1: Créer HelpIcon.swift**

```swift
//
//  HelpIcon.swift
//  CleanMySims
//

import SwiftUI

struct HelpIcon: View {
    let tooltip: String
    @State private var isHovering = false

    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 12))
            .foregroundStyle(Theme.Colors.secondaryText)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .popover(isPresented: $isHovering, arrowEdge: .trailing) {
                Text(tooltip)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .padding(12)
                    .frame(maxWidth: 200)
                    .background(Color.white)
            }
    }
}

#Preview {
    HelpIcon(tooltip: "Ceci est un texte d'aide explicatif.")
        .padding()
}
```

**Step 2: Commit**

```bash
git add CleanMySims/Views/Components/HelpIcon.swift
git commit -m "feat(ui): add HelpIcon component with tooltip"
```

---

## Task 3: Composant ProgressBar (animation de scan)

**Files:**
- Create: `CleanMySims/Views/Components/ProgressBar.swift`

**Step 1: Créer ProgressBar.swift**

```swift
//
//  ProgressBar.swift
// CleanMySims
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
```

**Step 2: Commit**

```bash
git add CleanMySims/Views/Components/ProgressBar.swift
git commit -m "feat(ui): add ProgressBar component with indeterminate mode"
```

---

## Task 4: Composant MinimalCard (cartes de catégorie)

**Files:**
- Create: `CleanMySims/Views/Components/MinimalCard.swift`

**Step 1: Créer MinimalCard.swift**

```swift
//
//  MinimalCard.swift
//  CleanMySims
//

import SwiftUI

struct MinimalCard: View {
    let title: String
    let type: CleanableItemType
    let size: Int64
    let helpText: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: type.iconName)
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.Colors.color(for: type))
                    Spacer()
                    HelpIcon(tooltip: helpText)
                }

                Spacer()

                Text(title)
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.primaryText)

                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(Color.white)
            .cornerRadius(Theme.Layout.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
            .shadow(
                color: isHovering ? Color.black.opacity(0.08) : Color.clear,
                radius: isHovering ? 8 : 0
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    MinimalCard(
        title: "Caches",
        type: .cache,
        size: 4_200_000_000,
        helpText: "Données temporaires des simulateurs"
    ) {
        print("Card tapped")
    }
    .padding()
    .frame(width: 200)
    .background(Theme.Colors.background)
}
```

**Step 2: Commit**

```bash
git add CleanMySims/Views/Components/MinimalCard.swift
git commit -m "feat(ui): add MinimalCard component for categories"
```

---

## Task 5: Composant ConfirmDialog

**Files:**
- Create: `CleanMySims/Views/Components/ConfirmDialog.swift`

**Step 1: Créer ConfirmDialog.swift**

```swift
//
//  ConfirmDialog.swift
//  CleanMySims
//

import SwiftUI

struct ConfirmDialog: View {
    let title: String
    let message: String
    let detail: String?
    let confirmTitle: String
    let isDangerous: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.primaryText)

            if let detail = detail {
                Text(detail)
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.primaryText)
            }

            Text(message)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Annuler") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                Button(confirmTitle) {
                    onConfirm()
                }
                .buttonStyle(.plain)
                .font(Theme.Fonts.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isDangerous ? Theme.Colors.danger : Theme.Colors.simulator)
                .cornerRadius(Theme.Layout.buttonCornerRadius)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 20)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        ConfirmDialog(
            title: "Supprimer cet élément ?",
            message: "2.1 GB seront libérés.",
            detail: "\"iPhone 15 Pro - iOS 17.2\"",
            confirmTitle: "Supprimer",
            isDangerous: true,
            onConfirm: { print("Confirmed") },
            onCancel: { print("Cancelled") }
        )
    }
}
```

**Step 2: Commit**

```bash
git add CleanMySims/Views/Components/ConfirmDialog.swift
git commit -m "feat(ui): add ConfirmDialog component"
```

---

## Task 6: Refaire ContentView (fenêtre immersive)

**Files:**
- Modify: `CleanMySims/ContentView.swift`

**Step 1: Modifier ContentView.swift**

Remplacer le contenu par :

```swift
//
//  ContentView.swift
//  CleanMySims
//

import SwiftUI

struct ContentView: View {
    @State private var selection: NavigationItem? = .dashboard
    @EnvironmentObject var simulatorManager: SimulatorManager

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection)
                .frame(width: Theme.Layout.sidebarWidth)

            Divider()

            Group {
                switch selection {
                case .dashboard, nil:
                    DashboardView()
                case .cache:
                    DetailListView(category: .cache)
                case .devices:
                    DetailListView(category: .virtualDevice)
                case .runtimes:
                    DetailListView(category: .runtimes)
                case .builds:
                    DetailListView(category: .builds)
                case .deviceSupport:
                    DetailListView(category: .deviceSupport)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Colors.background)
        .frame(width: Theme.Layout.windowWidth, height: Theme.Layout.windowHeight)
    }
}

#Preview {
    ContentView()
        .environmentObject(SimulatorManager())
}
```

**Step 2: Commit**

```bash
git add CleanMySims/ContentView.swift
git commit -m "feat(ui): rewrite ContentView with immersive window style"
```

---

## Task 7: Refaire SidebarView (custom flat)

**Files:**
- Modify: `CleanMySims/Views/SidebarView.swift`

**Step 1: Modifier SidebarView.swift**

Remplacer le contenu par :

```swift
//
//  SidebarView.swift
//  CleanMySims
//

import SwiftUI

enum NavigationItem: Hashable, Identifiable, CaseIterable {
    case dashboard
    case cache
    case devices
    case runtimes
    case builds
    case deviceSupport

    var id: Self { self }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .cache: return "Caches"
        case .devices: return "Simulateurs"
        case .runtimes: return "Runtimes"
        case .builds: return "Builds"
        case .deviceSupport: return "Device Support"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .cache: return "archivebox"
        case .devices: return "iphone"
        case .runtimes: return "gearshape.2"
        case .builds: return "hammer.circle"
        case .deviceSupport: return "iphone.circle"
        }
    }

    var helpText: String? {
        switch self {
        case .dashboard: return nil
        case .cache: return "Données temporaires des simulateurs : logs, caches de compilation, données téléchargées"
        case .devices: return "Les appareils virtuels iOS utilisés par Xcode pour tester vos apps"
        case .runtimes: return "Les versions d'iOS installées pour faire tourner les simulateurs"
        case .builds: return "Données de compilation générées par Xcode (DerivedData)"
        case .deviceSupport: return "Fichiers de support pour connecter des iPhone/iPad physiques à Xcode"
        }
    }

    var categoryType: CleanableItemType? {
        switch self {
        case .cache: return .cache
        case .devices: return .virtualDevice
        case .runtimes: return .runtimes
        case .builds: return .builds
        case .deviceSupport: return .deviceSupport
        default: return nil
        }
    }
}

struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @State private var hoveredItem: NavigationItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("CleanMySims")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Dashboard
            SidebarItem(
                item: .dashboard,
                selection: $selection,
                hoveredItem: $hoveredItem
            )

            // Separator
            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 1)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)

            // Categories
            ForEach([NavigationItem.cache, .devices, .runtimes, .builds, .deviceSupport], id: \.self) { item in
                SidebarItem(
                    item: item,
                    selection: $selection,
                    hoveredItem: $hoveredItem
                )
            }

            Spacer()
        }
        .background(Theme.Colors.sidebarBackground)
    }
}

struct SidebarItem: View {
    let item: NavigationItem
    @Binding var selection: NavigationItem?
    @Binding var hoveredItem: NavigationItem?
    @State private var isHelpHovered = false

    private var isSelected: Bool {
        selection == item
    }

    private var isHovered: Bool {
        hoveredItem == item && !isSelected
    }

    private var accentColor: Color {
        if let type = item.categoryType {
            return Theme.Colors.color(for: type)
        }
        return Theme.Colors.primaryText
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? accentColor : Theme.Colors.secondaryText)
                .frame(width: 20)

            Text(item.label)
                .font(Theme.Fonts.body)
                .foregroundStyle(isSelected ? Theme.Colors.primaryText : Theme.Colors.secondaryText)

            Spacer()

            if let helpText = item.helpText {
                HelpIcon(tooltip: helpText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accentColor.opacity(0.15))
                        .padding(.horizontal, 8)

                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 3)
                        .padding(.leading, 8)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.Colors.hoverBackground)
                        .padding(.horizontal, 8)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selection = item
        }
        .onHover { hovering in
            hoveredItem = hovering ? item : nil
        }
    }
}

#Preview {
    SidebarView(selection: .constant(.dashboard))
        .frame(width: 200, height: 400)
}
```

**Step 2: Commit**

```bash
git add CleanMySims/Views/SidebarView.swift
git commit -m "feat(ui): rewrite SidebarView with custom flat design"
```

---

## Task 8: Refaire DashboardView

**Files:**
- Modify: `CleanMySims/Views/DashboardView.swift`
- Delete: `CleanMySims/Views/Components/GlassyCard.swift`

**Step 1: Modifier DashboardView.swift**

Remplacer le contenu par :

```swift
//
//  DashboardView.swift
//  CleanMySims
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var simulatorManager: SimulatorManager
    @State private var navigateTo: CleanableItemType?

    private let categories: [(type: CleanableItemType, title: String, help: String)] = [
        (.cache, "Caches", "Données temporaires des simulateurs : logs, caches de compilation, données téléchargées"),
        (.virtualDevice, "Simulateurs", "Les appareils virtuels iOS utilisés par Xcode pour tester vos apps"),
        (.deviceSupport, "Device Support", "Fichiers de support pour connecter des iPhone/iPad physiques à Xcode"),
        (.runtimes, "Runtimes", "Les versions d'iOS installées pour faire tourner les simulateurs"),
        (.builds, "Builds", "Données de compilation générées par Xcode (DerivedData)")
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("Espace récupérable")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    Text(ByteCountFormatter.string(fromByteCount: simulatorManager.totalSize, countStyle: .file))
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.primaryText)
                        .contentTransition(.numericText(value: Double(simulatorManager.totalSize)))
                }
                .padding(.top, 48)
                .padding(.bottom, 32)

                // Cards Grid
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(categories, id: \.type) { category in
                            let size = simulatorManager.items
                                .filter { $0.type == category.type }
                                .reduce(0) { $0 + $1.size }

                            MinimalCard(
                                title: category.title,
                                type: category.type,
                                size: size,
                                helpText: category.help
                            ) {
                                // Navigate to detail view
                                navigateTo = category.type
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // Footer
                Button(action: {
                    simulatorManager.scan()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Rescan")
                    }
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(Theme.Layout.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Layout.buttonCornerRadius)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 32)
            }
            .opacity(simulatorManager.isScanning || simulatorManager.isCleaning ? 0.3 : 1.0)

            // Loading overlay
            if simulatorManager.isScanning {
                LoadingOverlay(
                    title: "Scan en cours...",
                    isIndeterminate: true
                )
            }

            if simulatorManager.isCleaning {
                LoadingOverlay(
                    title: "Nettoyage en cours...",
                    isIndeterminate: true
                )
            }
        }
        .background(Theme.Colors.background)
        .onAppear {
            if simulatorManager.items.isEmpty && !simulatorManager.isScanning {
                simulatorManager.scan()
            }
        }
    }
}

struct LoadingOverlay: View {
    let title: String
    let isIndeterminate: Bool

    var body: some View {
        VStack(spacing: 16) {
            ProgressBar(isIndeterminate: isIndeterminate)
                .frame(width: 300)

            Text(title)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(32)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 20)
    }
}

#Preview {
    DashboardView()
        .environmentObject(SimulatorManager())
        .frame(width: 600, height: 500)
}
```

**Step 2: Supprimer GlassyCard.swift**

```bash
rm CleanMySims/Views/Components/GlassyCard.swift
```

**Step 3: Commit**

```bash
git add CleanMySims/Views/DashboardView.swift
git add -A
git commit -m "feat(ui): rewrite DashboardView with MinimalCard grid, remove GlassyCard"
```

---

## Task 9: Refaire DetailListView

**Files:**
- Modify: `CleanMySims/Views/DetailListView.swift`

**Step 1: Modifier DetailListView.swift**

Remplacer le contenu par :

```swift
//
//  DetailListView.swift
//  CleanMySims
//

import SwiftUI

struct DetailListView: View {
    let category: CleanableItemType
    @EnvironmentObject var simulatorManager: SimulatorManager
    @State private var sortOrder: SortOrder = .defaultOrder
    @State private var showDeleteConfirm = false
    @State private var itemToDelete: CleanableItem?
    @State private var showCleanAllConfirm = false

    enum SortOrder {
        case defaultOrder
        case sizeAsc
        case sizeDesc

        var label: String {
            switch self {
            case .defaultOrder: return "Par défaut"
            case .sizeAsc: return "Taille ↑"
            case .sizeDesc: return "Taille ↓"
            }
        }

        var next: SortOrder {
            switch self {
            case .defaultOrder: return .sizeDesc
            case .sizeDesc: return .sizeAsc
            case .sizeAsc: return .defaultOrder
            }
        }
    }

    var filteredItems: [CleanableItem] {
        let items = simulatorManager.items.filter { $0.type == category }
        switch sortOrder {
        case .defaultOrder:
            return items
        case .sizeAsc:
            return items.sorted { $0.size < $1.size }
        case .sizeDesc:
            return items.sorted { $0.size > $1.size }
        }
    }

    var totalSize: Int64 {
        filteredItems.reduce(0) { $0 + $1.size }
    }

    var accentColor: Color {
        Theme.Colors.color(for: category)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(category.rawValue)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.primaryText)

                Spacer()

                HStack(spacing: 12) {
                    // Sort button
                    Menu {
                        Button("Par défaut") { sortOrder = .defaultOrder }
                        Button("Taille ↑") { sortOrder = .sizeAsc }
                        Button("Taille ↓") { sortOrder = .sizeDesc }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(sortOrder.label)
                        }
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.hoverBackground)
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)

                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(accentColor)

                    // Clean button
                    Button(action: {
                        showCleanAllConfirm = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Clean")
                        }
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.danger)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(filteredItems.isEmpty)
                    .opacity(filteredItems.isEmpty ? 0.5 : 1.0)
                }
            }
            .padding(16)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .fill(Theme.Colors.border)
                    .frame(height: 1),
                alignment: .bottom
            )

            // Content
            if filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.Colors.success)
                    Text("Tout est propre !")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            DetailRow(
                                item: item,
                                accentColor: accentColor
                            ) {
                                itemToDelete = item
                                showDeleteConfirm = true
                            }
                        }
                    }
                }
            }
        }
        .background(Theme.Colors.background)
        .overlay {
            if showDeleteConfirm, let item = itemToDelete {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ConfirmDialog(
                        title: "Supprimer cet élément ?",
                        message: "\(item.sizeString) seront libérés.",
                        detail: "\"\(item.name)\"",
                        confirmTitle: "Supprimer",
                        isDangerous: true,
                        onConfirm: {
                            simulatorManager.delete(item: item)
                            showDeleteConfirm = false
                            itemToDelete = nil
                        },
                        onCancel: {
                            showDeleteConfirm = false
                            itemToDelete = nil
                        }
                    )
                }
            }

            if showCleanAllConfirm {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ConfirmDialog(
                        title: "Nettoyer \(category.rawValue) ?",
                        message: "\(filteredItems.count) éléments, \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)) seront supprimés.",
                        detail: nil,
                        confirmTitle: "Nettoyer",
                        isDangerous: true,
                        onConfirm: {
                            simulatorManager.cleanItems(filteredItems)
                            showCleanAllConfirm = false
                        },
                        onCancel: {
                            showCleanAllConfirm = false
                        }
                    )
                }
            }
        }
    }
}

struct DetailRow: View {
    let item: CleanableItem
    let accentColor: Color
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let details = item.details {
                        Text(details)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }

                    Text(item.path)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.secondaryText.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Text(item.sizeString)
                .font(Theme.Fonts.mono)
                .foregroundStyle(Theme.Colors.secondaryText)

            // Actions (show on hover)
            if isHovered {
                HStack(spacing: 12) {
                    Button(action: {
                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 14))
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Ouvrir dans Finder")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Colors.danger)
                    }
                    .buttonStyle(.plain)
                    .help("Supprimer")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Theme.Colors.hoverBackground : Color.clear)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovered
            }
        }
        .overlay(
            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

#Preview {
    DetailListView(category: .cache)
        .environmentObject(SimulatorManager())
        .frame(width: 600, height: 400)
}
```

**Step 2: Ajouter méthode cleanItems dans SimulatorManager**

Ouvrir `CleanMySims/Logic/SimulatorManager.swift` et ajouter cette méthode :

```swift
func cleanItems(_ items: [CleanableItem]) {
    Task { @MainActor in
        isCleaning = true
        defer { isCleaning = false }

        for item in items {
            try? await Task.detached(priority: .background) {
                if item.isDirectory {
                    try FileManager.default.removeItem(atPath: item.path)
                } else {
                    try FileManager.default.removeItem(atPath: item.path)
                }
            }.value
        }

        // Rescan after cleaning
        scan()
    }
}
```

**Step 3: Commit**

```bash
git add CleanMySims/Views/DetailListView.swift
git add CleanMySims/Logic/SimulatorManager.swift
git commit -m "feat(ui): rewrite DetailListView with new styling and confirm dialogs"
```

---

## Task 10: Supprimer ScanningView et configurer fenêtre

**Files:**
- Delete: `CleanMySims/Views/Components/ScanningView.swift`
- Modify: `CleanMySims/CleanMySimsApp.swift`

**Step 1: Supprimer ScanningView**

```bash
rm CleanMySims/Views/Components/ScanningView.swift
```

**Step 2: Modifier CleanMySimsApp.swift pour fenêtre fixe**

```swift
//
//  CleanMySimsApp.swift
//  CleanMySims
//

import SwiftUI

@main
struct CleanMySimsApp: App {
    @StateObject private var simulatorManager = SimulatorManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(simulatorManager)
                .frame(
                    width: Theme.Layout.windowWidth,
                    height: Theme.Layout.windowHeight
                )
                .fixedSize()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Remove unnecessary menu items
            CommandGroup(replacing: .newItem) { }
        }
    }
}
```

**Step 3: Commit**

```bash
git add -A
git commit -m "feat(ui): remove ScanningView, configure fixed window with hidden title bar"
```

---

## Task 11: Mise à jour du modèle CleanableItem

**Files:**
- Modify: `CleanMySims/Models/CleanableItem.swift`

**Step 1: Vérifier et ajuster le modèle**

S'assurer que `CleanableItemType.rawValue` correspond aux labels du design :

```swift
//
//  CleanableItem.swift
//  CleanMySims
//

import Foundation

enum CleanableItemType: String, CaseIterable {
    case cache = "Caches"
    case deviceSupport = "Device Support"
    case virtualDevice = "Simulateurs"
    case runtimes = "Runtimes"
    case builds = "Builds"

    var iconName: String {
        switch self {
        case .cache: return "archivebox"
        case .deviceSupport: return "iphone.circle"
        case .virtualDevice: return "iphone"
        case .runtimes: return "gearshape.2"
        case .builds: return "hammer.circle"
        }
    }
}

struct CleanableItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let type: CleanableItemType
    let isDirectory: Bool
    let details: String?

    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
```

**Step 2: Commit**

```bash
git add CleanMySims/Models/CleanableItem.swift
git commit -m "feat(ui): update CleanableItem model with new labels"
```

---

## Task 12: Build et test final

**Step 1: Build le projet**

```bash
cd /Users/amaurygau/Developer/App-Macos/CleanMySims
xcodebuild -scheme CleanMySims -configuration Debug build
```

**Step 2: Vérifier les warnings/errors**

Corriger tous les problèmes de compilation.

**Step 3: Commit final**

```bash
git add -A
git commit -m "feat(ui): complete Zen Minimal redesign - flat design with pastel colors"
```

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Nouveau système Theme (couleurs pastel, typo) |
| 2 | Composant HelpIcon (tooltips) |
| 3 | Composant ProgressBar (animations) |
| 4 | Composant MinimalCard (cartes catégories) |
| 5 | Composant ConfirmDialog |
| 6 | ContentView (fenêtre immersive 800x550) |
| 7 | SidebarView (custom flat) |
| 8 | DashboardView (grille cartes, sans Clean All) |
| 9 | DetailListView (nouveau style + confirm dialogs) |
| 10 | Supprimer ScanningView + config fenêtre |
| 11 | Mise à jour CleanableItem |
| 12 | Build et test final |
