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
            HomeScreen(showsRootTabBar: true)
        case .camera:
            CameraScreen {
                appState.selectedTab = .home
            }
        case .friends:
            NavigationStack {
                FriendFeedScreen(showsRootTabBar: true)
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

struct AttachedBottomTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        ZStack(alignment: .top) {
            tabSurface

            Circle()
                .fill(AppColors.pureWhite)
                .frame(width: 66, height: 66)
                .overlay {
                    Circle()
                        .stroke(AppColors.border, lineWidth: 0.8)
                }
                .offset(y: -20)

            Button {
                selection = .camera
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                    .frame(width: 52, height: 52)
                    .background(AppColors.accentBlue, in: Circle())
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.86), lineWidth: 3)
                    }
            }
            .buttonStyle(.plain)
            .offset(y: -13)
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

                Spacer(minLength: 84)

                tabButton(.friends)
            }
            .padding(.horizontal, 46)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .frame(height: 60)
            .background(AppColors.pureWhite)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 19, weight: selection == tab ? .semibold : .regular))
                Text(tab.title)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(selection == tab ? AppColors.accentPink : AppColors.secondaryText)
            .frame(width: 64, height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}
