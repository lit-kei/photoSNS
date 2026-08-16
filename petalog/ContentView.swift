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
        Group {
            tabContent(for: appState.selectedTab)
        }
        .overlay(alignment: .bottom) {
            StickerUploadBanner(coordinator: appState.stickerUploadCoordinator)
                .padding(.horizontal, 16)
                .padding(.bottom, uploadBannerBottomPadding)
        }
        .sheet(isPresented: $appState.isShowingNotifications) {
            NavigationStack {
                HomeNotificationScreen()
                    .environmentObject(appState)
            }
            .presentationDragIndicator(.visible)
        }
    }

    private var uploadBannerBottomPadding: CGFloat {
        switch appState.selectedTab {
        case .home, .friends:
            72
        default:
            18
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
                FriendListScreen(showsRootTabBar: true)
            }
        case .memories:
            MemoriesScreen(showsRootTabBar: true)
        case .profile:
            NavigationStack {
                ProfileScreen(showsRootTabBar: true)
            }
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
                .frame(width: 62, height: 62)
                .overlay {
                    Circle()
                        .stroke(AppColors.border, lineWidth: 0.8)
                }
                .offset(y: -18)

            Button {
                selection = .camera
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                    .frame(width: 48, height: 48)
                    .background(AppColors.accentBlue, in: Circle())
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.86), lineWidth: 2.5)
                    }
            }
            .buttonStyle(.plain)
            .offset(y: -11)
            .accessibilityLabel("カメラ")
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.pureWhite)
    }

    private var tabSurface: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.border)
                .frame(maxWidth: .infinity)
                .frame(height: 0.8)

            HStack {
                tabButton(.home)
                tabButton(.memories)

                Spacer(minLength: 58)

                tabButton(.friends)
                tabButton(.profile)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .frame(maxWidth: 390, minHeight: 56)
            .background(AppColors.pureWhite)
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.pureWhite)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 17, weight: selection == tab ? .semibold : .regular))
                Text(tab.title)
                    .font(.system(size: 8.5, weight: .medium))
            }
            .foregroundStyle(selection == tab ? AppColors.accentPink : AppColors.secondaryText)
            .frame(width: 58, height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}
