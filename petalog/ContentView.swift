//
//  ContentView.swift
//  petalog
//

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(DebugThemeColors.mainAccentKey) private var debugMainAccentHex = DebugThemeColors.defaultMainAccentHex
    @AppStorage(DebugThemeColors.cameraAccentKey) private var debugCameraAccentHex = DebugThemeColors.defaultCameraAccentHex
    #if DEBUG
    @State private var showsDebugThemePicker = false
    #endif

    init() {
        Self.configureTabBarAppearance()
    }

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.pureWhite)
        appearance.shadowColor = UIColor(AppColors.border)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.accentPink)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppColors.mainText)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.secondaryText)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColors.secondaryText)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        Group {
            switch appState.authState {
            case .bootstrapping:
                ProgressView("petalogを準備中")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        PetalogMetalBackground()
                    }
            case .signedOut:
                AuthScreen()
            case .needsProfile(let email):
                UsernameSetupScreen(email: email)
            case .signedIn:
                signedInTabs
            }
        }
        .task {
            appState.stickerUploadCoordinator.setAppActive(scenePhase == .active)
            appState.stickerUploadCoordinator.prepareNotifications()
            if appState.authState == .bootstrapping {
                appState.bootstrap()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            appState.stickerUploadCoordinator.setAppActive(newValue == .active)
        }
        .preferredColorScheme(.light)
        .onChange(of: debugMainAccentHex) { _, _ in
            Self.configureTabBarAppearance()
        }
        .onChange(of: debugCameraAccentHex) { _, _ in
            Self.configureTabBarAppearance()
        }
        #if DEBUG
        .sheet(isPresented: $showsDebugThemePicker) {
            DebugThemePickerSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        #endif
        .alert("エラー", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    private var signedInTabs: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                tabContent(for: tab)
                    .tag(tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
            }
        }
        .tint(AppColors.accentPink)
        .toolbarBackground(AppColors.pureWhite, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .overlay(alignment: .top) {
            StickerUploadBanner(coordinator: appState.stickerUploadCoordinator)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if appState.selectedTab != .camera {
                cameraTabButton
                    .padding(.bottom, 14)
            }
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            Button {
                showsDebugThemePicker = true
            } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                    .frame(width: 40, height: 40)
                    .background(AppColors.elevatedSurface.opacity(0.96), in: Circle())
                    .overlay {
                        Circle().stroke(AppColors.border, lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 14)
            .accessibilityLabel("デバッグカラー設定")
        }
        #endif
    }

    private var cameraTabButton: some View {
        Button {
            appState.selectedTab = .camera
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
                .frame(width: 64, height: 64)
                .background {
                    Circle()
                        .fill(AppColors.accentBlue)
                        .shadow(color: AppColors.accentBlue.opacity(0.38), radius: 14, y: 7)
                }
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.82), lineWidth: 3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("カメラ")
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:
                HomeScreen()
        case .camera:
                CameraScreen {
                    appState.selectedTab = .home
                }
        case .friends:
                FriendAddScreen()
        case .memories:
                MemoriesScreen()
        case .profile:
                ProfileScreen()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}

#if DEBUG
private struct DebugThemePickerSheet: View {
    @AppStorage(DebugThemeColors.mainAccentKey) private var mainAccentHex = DebugThemeColors.defaultMainAccentHex
    @AppStorage(DebugThemeColors.cameraAccentKey) private var cameraAccentHex = DebugThemeColors.defaultCameraAccentHex

    private var mainAccent: Binding<Color> {
        Binding {
            DebugThemeColors.color(for: DebugThemeColors.mainAccentKey, fallbackHex: DebugThemeColors.defaultMainAccentHex)
        } set: { newValue in
            mainAccentHex = UIColor(newValue).petalogHexString
        }
    }

    private var cameraAccent: Binding<Color> {
        Binding {
            DebugThemeColors.color(for: DebugThemeColors.cameraAccentKey, fallbackHex: DebugThemeColors.defaultCameraAccentHex)
        } set: { newValue in
            cameraAccentHex = UIColor(newValue).petalogHexString
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("色を試すためのデバッグ機能です。選んだ色はこの端末に保存されます。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(3)

                VStack(spacing: 14) {
                    ColorPicker("メインカラー", selection: mainAccent, supportsOpacity: false)
                    colorPreview(hex: mainAccentHex, color: AppColors.accentPink)

                    Divider()

                    ColorPicker("カメラボタン", selection: cameraAccent, supportsOpacity: false)
                    colorPreview(hex: cameraAccentHex, color: AppColors.accentBlue)
                }
                .padding(18)
                .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 0.8)
                }

                Button {
                    DebugThemeColors.reset()
                    mainAccentHex = DebugThemeColors.defaultMainAccentHex
                    cameraAccentHex = DebugThemeColors.defaultCameraAccentHex
                } label: {
                    Label("デフォルトに戻す", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Spacer()
            }
            .padding(22)
            .background(PetalogMetalBackground())
            .navigationTitle("Theme Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func colorPreview(hex: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle().stroke(AppColors.border, lineWidth: 0.8)
                }
            Text(hex)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppColors.secondaryText)
            Spacer()
        }
    }
}
#endif
