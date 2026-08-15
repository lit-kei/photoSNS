//
//  ContentView.swift
//  petalog
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

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
        .toolbarBackground(AppColors.appBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .overlay(alignment: .top) {
            StickerUploadBanner(coordinator: appState.stickerUploadCoordinator)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
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
