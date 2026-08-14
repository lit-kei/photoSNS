//
//  MainScreens.swift
//  petalog
//

import SwiftUI
import UIKit

struct HomeScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    NavigationLink {
                        CameraScreen()
                    } label: {
                        Label("写真を撮る", systemImage: "camera.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    HStack(spacing: 12) {
                        NavigationLink {
                            GroupManagementScreen(initialMode: .create)
                        } label: {
                            Label("グループを作る", systemImage: "person.3.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .frame(maxWidth: .infinity)

                        NavigationLink {
                            GroupManagementScreen(initialMode: .join)
                        } label: {
                            Label("参加する", systemImage: "qrcode.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("今日のグループ")
                            .font(.title2.bold())
                            .foregroundStyle(PetalogTheme.text)

                        if appState.groups.isEmpty {
                            EmptyStateView(systemImage: "person.3.sequence.fill", title: "まだグループがありません", message: "友達とグループを作るか、招待コードで参加すると今日の絵日記を始められます。")
                        } else {
                            ForEach(appState.groups) { group in
                                NavigationLink {
                                    DiaryScreen(group: group)
                                } label: {
                                    GroupActivityCard(group: group)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PetalogTheme.background)
            .navigationTitle("petalog")
            .toolbar {
                NavigationLink {
                    GroupManagementScreen(initialMode: .list)
                } label: {
                    Image(systemName: "person.2.badge.gearshape.fill")
                }
                .accessibilityLabel("グループ管理")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Date().petalogDisplayDate)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PetalogTheme.secondaryText)

            Text("今日の思い出をつくろう")
                .font(.largeTitle.bold())
                .foregroundStyle(PetalogTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            if let user = appState.currentUser {
                Text("\(user.avatar) \(user.displayName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PetalogTheme.secondaryText)
            }
        }
    }
}

private struct GroupActivityCard: View {
    let group: PetalogGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(spacing: 10) {
                    Text(group.icon)
                        .font(.title2)
                        .frame(width: 42, height: 42)
                        .background(PetalogTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                            .foregroundStyle(PetalogTheme.text)
                        Text("招待コード \(group.inviteCode)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PetalogTheme.secondaryText)
                    }
                }

                Spacer()
                MemberAvatarStack(avatars: group.memberAvatars)
            }

            DiaryBackgroundView(background: .notebook)
                .frame(height: 150)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.title2)
                            .foregroundStyle(PetalogTheme.primary)
                        Text("今日の絵日記を見る")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PetalogTheme.text)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("\(group.memberIds.count)人 / \(group.diaryCount)枚の絵日記")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PetalogTheme.secondaryText)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PetalogTheme.border, lineWidth: 1)
        }
    }
}

struct MemoriesScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("1日1枚の絵日記")
                        .font(.largeTitle.bold())
                        .foregroundStyle(PetalogTheme.text)

                    if appState.groups.isEmpty {
                        EmptyStateView(systemImage: "book.closed.fill", title: "思い出はこれから", message: "グループでステッカーを貼ると、1日1枚の絵日記がここに並びます。")
                    } else {
                        ForEach(appState.groups) { group in
                            NavigationLink {
                                DiaryScreen(group: group)
                            } label: {
                                HStack(spacing: 14) {
                                    Text(group.icon)
                                        .font(.largeTitle)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.name)
                                            .font(.headline)
                                            .foregroundStyle(PetalogTheme.text)
                                        Text("今日 / \(group.diaryCount)枚")
                                            .font(.subheadline)
                                            .foregroundStyle(PetalogTheme.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(PetalogTheme.secondaryText)
                                }
                                .padding(14)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(PetalogTheme.background)
            .navigationTitle("思い出")
        }
    }
}

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var displayName = ""
    @State private var avatar = "🙂"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        Text(avatar)
                            .font(.system(size: 72))
                            .frame(width: 104, height: 104)
                            .background(.white)
                            .clipShape(Circle())
                            .overlay { Circle().stroke(PetalogTheme.border, lineWidth: 1) }

                        TextField("ユーザー名", text: $displayName)
                            .font(.title3.weight(.bold))
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 8) {
                            ForEach(["🙂", "😆", "😎", "😊", "🤩", "🌟"], id: \.self) { candidate in
                                Button(candidate) { avatar = candidate }
                                    .font(.title2)
                                    .frame(width: 42, height: 42)
                                    .background(candidate == avatar ? PetalogTheme.primary.opacity(0.16) : .white)
                                    .clipShape(Circle())
                            }
                        }

                        Button {
                            Task { await appState.updateProfile(displayName: displayName, avatar: avatar) }
                        } label: {
                            Label("プロフィールを保存", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        HStack(spacing: 12) {
                            ProfileStat(title: "グループ", value: "\(appState.groups.count)")
                            ProfileStat(title: "参加中", value: "\(appState.groups.reduce(0) { $0 + $1.memberIds.count })")
                            ProfileStat(title: "絵日記", value: "\(appState.groups.reduce(0) { $0 + $1.diaryCount })")
                        }
                    }

                    EmptyStateView(systemImage: "scissors", title: "作ったステッカー", message: "投稿したステッカーは、次の同期画面で自分だけの一覧として表示していきます。")
                }
                .padding(20)
            }
            .background(PetalogTheme.background)
            .navigationTitle("プロフィール")
            .onAppear {
                displayName = appState.currentUser?.displayName ?? ""
                avatar = appState.currentUser?.avatar ?? "🙂"
            }
        }
    }
}

private struct ProfileStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(PetalogTheme.text)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PetalogTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
