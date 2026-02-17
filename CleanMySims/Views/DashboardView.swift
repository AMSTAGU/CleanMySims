//
//  DashboardView.swift
//  CleanMySims
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var simulatorManager: SimulatorManager

    private let categories: [(type: CleanableItemType, title: String, help: String)] = [
        (.cache, "Caches", "Données temporaires des simulateurs : logs, caches de compilation, données téléchargées"),
        (.virtualDevice, "Simulateurs", "Les appareils virtuels iOS utilisés par Xcode pour tester vos apps"),
        (.deviceSupport, "Device Support", "Fichiers de support pour connecter des iPhone/iPad physiques à Xcode"),
        (.runtimes, "Runtimes", "Les versions d'iOS installées pour faire tourner les simulateurs"),
        (.builds, "Builds", "Données de compilation générées par Xcode (DerivedData)")
    ]

    private func sizeForType(_ type: CleanableItemType) -> Int64 {
        simulatorManager.items
            .filter { $0.type == type }
            .reduce(0) { $0 + $1.size }
    }

    private var pieSlices: [PieSlice] {
        categories.map { category in
            PieSlice(
                value: Double(sizeForType(category.type)),
                color: Theme.Colors.color(for: category.type),
                label: category.title
            )
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
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
                    .padding(.top, 40)
                    .padding(.bottom, 24)

                    // Pie Chart
                    if simulatorManager.totalSize > 0 {
                        PieChart(slices: pieSlices, size: 140)
                            .padding(.bottom, 24)

                        // Legend
                        HStack(spacing: 16) {
                            ForEach(categories, id: \.type) { category in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Theme.Colors.color(for: category.type))
                                        .frame(width: 8, height: 8)
                                    Text(category.title)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }

                    // Cards Grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(categories, id: \.type) { category in
                            MinimalCard(
                                title: category.title,
                                type: category.type,
                                size: sizeForType(category.type),
                                helpText: category.help
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 80) // Space for floating button
                }
            }
            .opacity(simulatorManager.isScanning || simulatorManager.isCleaning ? 0.3 : 1.0)

            // Floating Rescan button
            VStack {
                Spacer()
                HStack {
                    Spacer()
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
                        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.bottom, 24)
            }

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
