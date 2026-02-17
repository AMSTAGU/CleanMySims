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
                                // Navigate to detail view - handled by parent
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
