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
        .onReceive(NotificationCenter.default.publisher(for: .petalogOpenNotifications)) { _ in
            appState.openNotifications()
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
            }
        }
        .tint(AppColors.accentPink)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .top) {
            StickerUploadBanner(coordinator: appState.stickerUploadCoordinator)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if appState.selectedTab != .camera {
                AttachedBottomTabBar(selection: $appState.selectedTab)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $appState.isShowingNotifications) {
            NavigationStack {
                HomeNotificationScreen()
                    .environmentObject(appState)
            }
            .presentationDragIndicator(.visible)
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

private struct AttachedBottomTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        ZStack(alignment: .top) {
            tabSurface

            Circle()
                .fill(AppColors.pureWhite)
                .frame(width: 78, height: 78)
                .overlay {
                    Circle()
                        .stroke(AppColors.border, lineWidth: 0.8)
                }
                .offset(y: -25)

            Button {
                selection = .camera
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                    .frame(width: 62, height: 62)
                    .background(AppColors.accentBlue, in: Circle())
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.86), lineWidth: 3)
                    }
            }
            .buttonStyle(.plain)
            .offset(y: -17)
            .accessibilityLabel("カメラ")
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.pureWhite)
    }

    private var tabSurface: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 0.8)

            HStack {
                tabButton(.home)

                Spacer(minLength: 96)

                tabButton(.friends)
            }
            .padding(.horizontal, 52)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(height: 76)
            .background(AppColors.pureWhite)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 21, weight: selection == tab ? .semibold : .regular))
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selection == tab ? AppColors.accentPink : AppColors.secondaryText)
            .frame(width: 68, height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}
