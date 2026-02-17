//
//  DashboardView.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var simulatorManager: SimulatorManager
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Header Stats
                    VStack(spacing: 5) {
                        Text("Recoverable Space")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        
                        Text(ByteCountFormatter.string(fromByteCount: simulatorManager.totalSize, countStyle: .file))
                            .font(Theme.Fonts.title)
                            .foregroundStyle(Theme.Colors.primaryText)
                            .shadow(color: Theme.Colors.accentPurple.opacity(0.5), radius: 10, x: 0, y: 5)
                            .contentTransition(.numericText(value: Double(simulatorManager.totalSize)))
                    }
                    .padding(.top, 40)
                    
                    // Categories Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 20)], spacing: 20) {
                        makeCard(title: "Caches", type: .cache, color: Theme.Colors.accentBlue)
                        makeCard(title: "Devices", type: .virtualDevice, color: Theme.Colors.accentPurple)
                        makeCard(title: "Device Support", type: .deviceSupport, color: Theme.Colors.accentOrange)
                        makeCard(title: "Runtimes", type: .runtimes, color: Theme.Colors.accentGreen)
                        makeCard(title: "Builds", type: .builds, color: Theme.Colors.accentPink)
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer(minLength: 40)
                    
                    // Action Buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            simulatorManager.scan()
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Rescan")
                            }
                            .font(Theme.Fonts.headline)
                            .padding()
                            .frame(height: 50)
                            .background(Material.ultraThin)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            simulatorManager.cleanAll()
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Clean All")
                            }
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(height: 50)
                            .frame(maxWidth: 200)
                            .background(
                                LinearGradient(
                                    colors: [Theme.Colors.accentPurple, Theme.Colors.accentPink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Theme.Colors.accentPink.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        .disabled(simulatorManager.totalSize == 0)
                        .opacity(simulatorManager.totalSize == 0 ? 0.5 : 1.0)
                    }
                    .padding(.bottom, 40)
                }
            }
            .opacity(simulatorManager.isScanning || simulatorManager.isCleaning ? 0 : 1)
            
            if simulatorManager.isScanning {
                ScanningView(title: "Scanning Simulators...", icon: "magnifyingglass", rotateIcon: true)
                    .transition(.opacity)
            }
            
            if simulatorManager.isCleaning {
                ScanningView(title: "Cleaning Simulators...", icon: "sparkles", rotateIcon: false)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if simulatorManager.items.isEmpty && !simulatorManager.isScanning {
                simulatorManager.scan()
            }
        }
    }
    
    @ViewBuilder
    func makeCard(title: String, type: CleanableItemType, color: Color) -> some View {
        GlassyCard {
            VStack(spacing: 15) {
                Image(systemName: type.iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 5) {
                    Text(title)
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.primaryText)
                    
                    let size = simulatorManager.items.filter { $0.type == type }.reduce(0) { $0 + $1.size }
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}
