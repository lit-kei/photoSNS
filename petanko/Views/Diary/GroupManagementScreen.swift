import PhotosUI
import SwiftUI
import UIKit

struct GroupManagementScreen: View {
    enum Mode {
        case list
        case create
        case join
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let initialMode: Mode
    @State private var groupName = ""
    @State private var groupIcon = "📘"
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var selectedIconData: Data?
    @State private var inviteCode = ""
    @State private var candidateGroup: PetankoGroup?
    @State private var lookupTask: Task<Void, Never>?
    @State private var isJoining = false
    @State private var groupToLeave: PetankoGroup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if initialMode == .list {
                    ControlSection(title: "所属グループ") {
                        if appState.groups.isEmpty {
                            EmptyStateView(systemImage: "person.3.fill", title: "グループなし", message: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(appState.groups) { group in
                                    HStack(spacing: 12) {
                                        GroupIconView(icon: group.icon, iconURL: group.iconURL, imageData: nil, size: 44, fontSize: 22)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.name).font(.headline)
                                            Text("\(group.memberIds.count)人 / 招待 \(group.inviteCode)")
                                                .font(.subheadline)
                                                .foregroundStyle(AppColors.secondaryText)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(AppColors.surface.opacity(0.94))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                                }
                            }
                        }
                    }
                }

                if initialMode != .join {
                    ControlSection(title: "グループを作る") {
                        VStack(spacing: 12) {
                            TextField("グループ名", text: $groupName)
                                .textFieldStyle(.plain)
                                .metalTextField()

                            PhotosPicker(selection: $selectedIconItem, matching: .images, photoLibrary: .shared()) {
                                HStack(spacing: 12) {
                                    GroupIconView(icon: groupIcon, iconURL: nil, imageData: selectedIconData, size: 52, fontSize: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("写真からアイコンを選ぶ")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(AppColors.mainText)
                                    }
                                    Spacer()
                                    Image(systemName: "photo")
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                                .padding(12)
                                .background(AppColors.surface.opacity(0.94))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                        .stroke(AppColors.border, lineWidth: 0.8)
                                }
                            }
                            .buttonStyle(.plain)
                            .onChange(of: selectedIconItem) { _, item in
                                Task {
                                    guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                                    selectedIconData = data
                                }
                            }

                            HStack(spacing: 8) {
                                ForEach(["📘", "🏖", "🎒", "🎪", "🎂", "🎤"], id: \.self) { icon in
                                    Button(icon) {
                                        groupIcon = icon
                                        selectedIconData = nil
                                        selectedIconItem = nil
                                    }
                                        .font(.title2)
                                        .frame(width: 42, height: 42)
                                        .background(icon == groupIcon ? AppColors.silver.opacity(0.34) : AppColors.surface.opacity(0.94))
                                        .clipShape(Circle())
                                }
                            }

                            Button {
                                Task {
                                    let didCreate = await appState.createGroup(name: groupName, icon: groupIcon, iconImageData: selectedIconData)
                                    if didCreate, initialMode == .create {
                                        dismiss()
                                        return
                                    }
                                    guard didCreate else { return }
                                    groupName = ""
                                    selectedIconData = nil
                                    selectedIconItem = nil
                                }
                            } label: {
                                Label("グループを作る", systemImage: "person.badge.plus")
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(groupName.trimmedForPetanko.isEmpty)
                        }
                    }
                }

                if initialMode != .create {
                    ControlSection(title: "グループに参加する") {
                        VStack(spacing: 12) {
                            TextField("招待コード", text: $inviteCode)
                                .textInputAutocapitalization(.characters)
                                .textFieldStyle(.plain)
                                .metalTextField()
                                .onChange(of: inviteCode) { _, code in
                                    scheduleLookup(for: code)
                                }

                            if let candidateGroup {
                                GroupCandidateCard(group: candidateGroup)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            Button {
                                Task {
                                    isJoining = true
                                    await appState.joinGroup(inviteCode: inviteCode)
                                    inviteCode = ""
                                    candidateGroup = nil
                                    isJoining = false
                                }
                            } label: {
                                if isJoining {
                                    ProgressView()
                                } else {
                                    Label("参加する", systemImage: "person.badge.plus")
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                            .disabled(inviteCode.trimmedForPetanko.isEmpty || isJoining)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background {
            PetankoMetalBackground()
        }
        .navigationTitle("グループ")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "グループから脱退しますか？",
            isPresented: Binding(
                get: { groupToLeave != nil },
                set: { if !$0 { groupToLeave = nil } }
            ),
            presenting: groupToLeave
        ) { group in
            Button("脱退", role: .destructive) {
                Task {
                    let didLeave = await appState.leaveGroup(group)
                    if didLeave {
                        groupToLeave = nil
                    }
                }
            }
            Button("キャンセル", role: .cancel) {
                groupToLeave = nil
            }
        } message: { group in
            Text("\(group.name)から脱退します。")
        }
    }

    private func scheduleLookup(for code: String) {
        lookupTask?.cancel()
        candidateGroup = nil

        let trimmedCode = code.trimmedForPetanko.uppercased()
        guard trimmedCode.count >= 4 else { return }

        lookupTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            let group = await appState.findGroup(inviteCode: trimmedCode)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                candidateGroup = group
            }
        }
    }
}

struct GroupEditScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let group: PetankoGroup
    @State private var groupName: String
    @State private var groupIcon: String
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var selectedIconData: Data?
    @State private var isSaving = false
    @State private var isConfirmingLeave = false
    @State private var selectedMemberProfile: AppUser?
    @State private var loadingMemberIds: Set<String> = []

    init(group: PetankoGroup) {
        self.group = group
        _groupName = State(initialValue: group.name)
        _groupIcon = State(initialValue: group.icon)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("グループ編集")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppColors.mainText)

                ControlSection(title: "アイコン") {
                    VStack(spacing: 12) {
                        PhotosPicker(selection: $selectedIconItem, matching: .images, photoLibrary: .shared()) {
                            HStack(spacing: 12) {
                                GroupIconView(icon: groupIcon, iconURL: group.iconURL, imageData: selectedIconData, size: 56, fontSize: 25)
                                Text("写真から選ぶ")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppColors.mainText)
                                Spacer()
                                Image(systemName: "photo")
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                            .padding(12)
                            .background(AppColors.surface.opacity(0.94))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                    .stroke(AppColors.border, lineWidth: 0.8)
                            }
                        }
                        .buttonStyle(.plain)
                        .onChange(of: selectedIconItem) { _, item in
                            Task {
                                guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                                selectedIconData = data
                            }
                        }

                        HStack(spacing: 8) {
                            ForEach(["📘", "🏖", "🎒", "🎪", "🎂", "🎤"], id: \.self) { icon in
                                Button(icon) {
                                    groupIcon = icon
                                    selectedIconData = nil
                                    selectedIconItem = nil
                                }
                                .font(.title2)
                                .frame(width: 42, height: 42)
                                .background(icon == groupIcon && selectedIconData == nil ? AppColors.silver.opacity(0.34) : AppColors.surface.opacity(0.94))
                                .clipShape(Circle())
                            }
                        }
                    }
                }

                ControlSection(title: "グループ名") {
                    TextField("グループ名", text: $groupName)
                        .textFieldStyle(.plain)
                        .metalTextField()
                }

                Button {
                    Task {
                        isSaving = true
                        await appState.updateGroup(group: group, name: groupName, icon: groupIcon, iconImageData: selectedIconData)
                        isSaving = false
                        dismiss()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(AppColors.mainText)
                    } else {
                        Label("保存する", systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(groupName.trimmedForPetanko.isEmpty || isSaving)

                ControlSection(title: "メンバー") {
                    VStack(spacing: 0) {
                        ForEach(memberSummaries) { member in
                            GroupMemberRow(
                                member: member,
                                isCurrentUser: member.id == appState.currentUser?.id,
                                isOwner: member.id == group.ownerId,
                                isLoading: loadingMemberIds.contains(member.id)
                            ) {
                                Task { await openMemberProfile(member) }
                            }
                        }
                    }
                }

                Button(role: .destructive) {
                    isConfirmingLeave = true
                } label: {
                    Label("グループから脱退", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActionButtonStyle(foregroundColor: AppColors.destructiveRed))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background {
            PetankoMetalBackground()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedMemberProfile) { user in
            FriendProfileScreen(user: user)
        }
        .confirmationDialog("グループから脱退しますか？", isPresented: $isConfirmingLeave, titleVisibility: .visible) {
            Button("脱退", role: .destructive) {
                Task {
                    let didLeave = await appState.leaveGroup(group)
                    if didLeave {
                        dismiss()
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(group.name)から脱退します。")
        }
    }

    private var memberSummaries: [GroupMemberSummary] {
        group.memberIds.enumerated().map { index, id in
            let name = group.memberNames.indices.contains(index) ? group.memberNames[index] : ""
            let avatar = group.memberAvatars.indices.contains(index) ? group.memberAvatars[index] : ""
            return GroupMemberSummary(
                id: id,
                name: name.isEmpty ? "petanko user" : name,
                avatarValue: avatar.isEmpty ? "system:person.fill" : avatar
            )
        }
    }

    private func openMemberProfile(_ member: GroupMemberSummary) async {
        guard loadingMemberIds.insert(member.id).inserted else { return }
        let profile = await appState.loadUserProfile(userId: member.id)
        loadingMemberIds.remove(member.id)
        selectedMemberProfile = profile ?? member.fallbackUser
    }
}

private struct GroupMemberSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let avatarValue: String

    var fallbackUser: AppUser {
        AppUser(
            id: id,
            displayName: name,
            avatar: isImageURL ? "" : displayAvatar,
            avatarURL: isImageURL ? avatarValue : nil
        )
    }

    var isSystemImage: Bool {
        avatarValue.hasPrefix("system:")
    }

    var systemImageName: String {
        String(avatarValue.dropFirst("system:".count))
    }

    var isImageURL: Bool {
        avatarValue.hasPrefix("http://") || avatarValue.hasPrefix("https://")
    }

    var displayAvatar: String {
        isSystemImage ? "" : avatarValue
    }
}

private struct GroupMemberRow: View {
    let member: GroupMemberSummary
    let isCurrentUser: Bool
    let isOwner: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                GroupMemberAvatar(member: member)

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if isCurrentUser {
                            Text("あなた")
                        }
                        if isOwner {
                            Text("オーナー")
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(AppColors.mainText)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.darkSilver)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 0.8)
        }
        .disabled(isLoading)
    }
}

private struct GroupMemberAvatar: View {
    let member: GroupMemberSummary

    var body: some View {
        Group {
            if member.isImageURL {
                RemoteImageView(urlString: member.avatarValue) {
                    placeholder
                }
            } else if member.isSystemImage {
                placeholder
            } else {
                Text(member.avatarValue)
                    .font(.system(size: 20))
            }
        }
        .frame(width: 42, height: 42)
        .background(AppColors.chromeHighlight.opacity(0.78))
        .clipShape(Circle())
        .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
    }

    private var placeholder: some View {
        Image(systemName: member.isSystemImage ? member.systemImageName : "person.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(AppColors.secondaryText)
    }
}

private struct GroupCandidateCard: View {
    let group: PetankoGroup

    var body: some View {
        HStack(spacing: 12) {
            GroupIconView(icon: group.icon, iconURL: group.iconURL, imageData: nil, size: 46, fontSize: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Text("\(group.memberIds.count)人が参加中")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer()

            Text("候補")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(12)
        .background(AppColors.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }
}

struct GroupIconView: View {
    let icon: String
    let iconURL: String?
    let imageData: Data?
    let size: CGFloat
    let fontSize: CGFloat

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let iconURL, !iconURL.isEmpty {
                RemoteImageView(urlString: iconURL) {
                    Text(icon)
                        .font(.system(size: fontSize))
                }
            } else {
                Text(icon)
                    .font(.system(size: fontSize))
            }
        }
        .frame(width: size, height: size)
        .background(AppColors.chromeHighlight.opacity(0.78))
        .clipShape(Circle())
        .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
    }
}
