//
//  ContentView.swift
//  petalog
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

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
            if appState.authState == .bootstrapping {
                appState.bootstrap()
            }
        }
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
            HomeScreen()
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)

            CameraScreen {
                appState.selectedTab = .home
            }
            .tabItem { Label(AppTab.camera.title, systemImage: AppTab.camera.systemImage) }
            .tag(AppTab.camera)

            MemoriesScreen()
                .tabItem { Label(AppTab.memories.title, systemImage: AppTab.memories.systemImage) }
                .tag(AppTab.memories)

            ProfileScreen()
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            if appState.selectedTab != .camera {
                FloatingTabBar(selection: $appState.selectedTab)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }
        }
        .tint(AppColors.mainText)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
