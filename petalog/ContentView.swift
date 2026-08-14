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
                    .background(PetalogTheme.background)
            case .signedOut:
                AuthScreen()
            case .needsProfile(let email):
                UsernameSetupScreen(email: email)
            case .signedIn:
                TabView(selection: $appState.selectedTab) {
                    HomeScreen()
                        .tabItem { Label("ホーム", systemImage: "house.fill") }
                        .tag(AppTab.home)

                    CameraScreen()
                        .tabItem { Label("カメラ", systemImage: "camera.fill") }
                        .tag(AppTab.camera)

                    MemoriesScreen()
                        .tabItem { Label("思い出", systemImage: "book.pages.fill") }
                        .tag(AppTab.memories)

                    ProfileScreen()
                        .tabItem { Label("プロフィール", systemImage: "person.crop.circle.fill") }
                        .tag(AppTab.profile)
                }
                .tint(PetalogTheme.primary)
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
