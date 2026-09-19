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
    @State private var groupIcon = GroupIconPreset.petankoValue
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var selectedIconData: Data?
    @State private var inviteCode = ""
    @State private var candidateGroup: PetankoGroup?
    @State private var lookupTask: Task<Void, Never>?
    @State private var isCreating = false
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
                            GroupIconPicker(
                                icon: $groupIcon,
                                selectedIconItem: $selectedIconItem,
                                selectedIconData: $selectedIconData,
                                existingIconURL: nil,
                                previewSize: 118,
                                onPresetSelected: {},
                                onPhotoSelected: {}
                            )

                            TextField("グループ名", text: $groupName)
                                .textFieldStyle(.plain)
                                .metalTextField()

                            Button {
                                Task {
                                    isCreating = true
                                    let didCreate = await appState.createGroup(name: groupName, icon: groupIcon, iconImageData: selectedIconData)
                                    isCreating = false
                                    if didCreate, initialMode == .create {
                                        dismiss()
                                        return
                                    }
                                    guard didCreate else { return }
                                    groupName = ""
                                    groupIcon = GroupIconPreset.petankoValue
                                    selectedIconData = nil
                                    selectedIconItem = nil
                                }
                            } label: {
                                if isCreating {
                                    ProgressView()
                                        .tint(AppColors.mainText)
                                } else {
                                    Label("グループを作る", systemImage: "person.badge.plus")
                                }
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(groupName.trimmedForPetanko.isEmpty || isCreating)
                            .opacity(groupName.trimmedForPetanko.isEmpty || isCreating ? 0.48 : 1)
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
    @State private var isRemovingExistingIconImage = false
    @State private var isSaving = false
    @State private var isConfirmingLeave = false
    @State private var selectedMemberProfile: AppUser?
    @State private var loadingMemberIds: Set<String> = []

    init(group: PetankoGroup) {
        self.group = group
        _groupName = State(initialValue: group.name)
        _groupIcon = State(initialValue: GroupIconPreset.normalizedValue(group.icon))
    }

    private var currentGroup: PetankoGroup {
        appState.groups.first(where: { $0.id == group.id }) ?? group
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ControlSection(title: "アイコン") {
                    GroupIconPicker(
                        icon: $groupIcon,
                        selectedIconItem: $selectedIconItem,
                        selectedIconData: $selectedIconData,
                        existingIconURL: isRemovingExistingIconImage ? nil : currentGroup.iconURL,
                        previewSize: 118,
                        onPresetSelected: {
                            isRemovingExistingIconImage = true
                        },
                        onPhotoSelected: {
                            isRemovingExistingIconImage = false
                        }
                    )
                }

                ControlSection(title: "グループ名") {
                    TextField("グループ名", text: $groupName)
                        .textFieldStyle(.plain)
                        .metalTextField()
                }

                Button {
                    Task {
                        isSaving = true
                        await appState.updateGroup(
                            group: currentGroup,
                            name: groupName,
                            icon: groupIcon,
                            iconImageData: selectedIconData,
                            removeIconImage: isRemovingExistingIconImage && selectedIconData == nil
                        )
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
                .opacity(groupName.trimmedForPetanko.isEmpty || isSaving ? 0.48 : 1)

                ControlSection(title: "メンバー") {
                    VStack(spacing: 0) {
                        ForEach(memberSummaries) { member in
                            GroupMemberRow(
                                member: member,
                                isCurrentUser: member.id == appState.currentUser?.id,
                                isOwner: member.id == currentGroup.ownerId,
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
        .navigationTitle("グループ編集")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedMemberProfile) { user in
            FriendProfileScreen(user: user)
        }
        .task {
            await appState.refreshGroup(group.id)
            syncFormWithCurrentGroup()
        }
        .confirmationDialog("グループから脱退しますか？", isPresented: $isConfirmingLeave, titleVisibility: .visible) {
            Button("脱退", role: .destructive) {
                Task {
                    let didLeave = await appState.leaveGroup(currentGroup)
                    if didLeave {
                        dismiss()
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(currentGroup.name)から脱退します。")
        }
    }

    private var memberSummaries: [GroupMemberSummary] {
        currentGroup.memberIds.enumerated().map { index, id in
            let name = currentGroup.memberNames.indices.contains(index) ? currentGroup.memberNames[index] : ""
            let avatar = currentGroup.memberAvatars.indices.contains(index) ? currentGroup.memberAvatars[index] : ""
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

    private func syncFormWithCurrentGroup() {
        groupName = currentGroup.name
        groupIcon = GroupIconPreset.normalizedValue(currentGroup.icon)
        selectedIconItem = nil
        selectedIconData = nil
        isRemovingExistingIconImage = false
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

private struct GroupIconPreset: Identifiable, Hashable {
    static let petankoValue = "petanko"

    let value: String
    let color: Color?

    var id: String { value }

    static let colorOptions: [GroupIconPreset] = [
        GroupIconPreset(value: "color:#C477A2", color: Color(red: 0.77, green: 0.47, blue: 0.64)),
        GroupIconPreset(value: "color:#F7B267", color: Color(red: 0.97, green: 0.70, blue: 0.40)),
        GroupIconPreset(value: "color:#91C27C", color: Color(red: 0.57, green: 0.76, blue: 0.49)),
        GroupIconPreset(value: "color:#6699E8", color: Color(red: 0.40, green: 0.60, blue: 0.91)),
        GroupIconPreset(value: "color:#FFB31A", color: Color(red: 1.0, green: 0.70, blue: 0.10))
    ]

    static func normalizedValue(_ value: String) -> String {
        if value == petankoValue || value.hasPrefix("color:#") {
            return value
        }
        return petankoValue
    }
}

private struct GroupIconPicker: View {
    @Binding var icon: String
    @Binding var selectedIconItem: PhotosPickerItem?
    @Binding var selectedIconData: Data?
    let existingIconURL: String?
    let previewSize: CGFloat
    let onPresetSelected: () -> Void
    let onPhotoSelected: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            GroupIconView(
                icon: icon,
                iconURL: existingIconURL,
                imageData: selectedIconData,
                size: previewSize,
                fontSize: previewSize * 0.44
            )
            .frame(maxWidth: .infinity)

            Divider()
                .padding(.vertical, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedIconItem, matching: .images, photoLibrary: .shared()) {
                        CircleIconOption(isSelected: selectedIconData != nil) {
                            Image(systemName: "plus")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectPreset(GroupIconPreset.petankoValue)
                    } label: {
                        CircleIconOption(isSelected: selectedIconData == nil && icon == GroupIconPreset.petankoValue) {
                            Image("BootSplashIcon")
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(GroupIconPreset.colorOptions) { option in
                        Button {
                            selectPreset(option.value)
                        } label: {
                            CircleIconOption(isSelected: selectedIconData == nil && icon == option.value) {
                                Circle()
                                    .fill(option.color ?? AppColors.chromeHighlight)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.vertical, 2)
            }
        }
        .onChange(of: selectedIconItem) { _, item in
            Task {
                guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                selectedIconData = data
                onPhotoSelected()
            }
        }
    }

    private func selectPreset(_ value: String) {
        icon = value
        selectedIconData = nil
        selectedIconItem = nil
        onPresetSelected()
    }
}

private struct CircleIconOption<Content: View>: View {
    let isSelected: Bool
    let content: () -> Content

    init(isSelected: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isSelected = isSelected
        self.content = content
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.surface.opacity(0.96))
            content()
                .clipShape(Circle())

            Circle()
                .stroke(isSelected ? AppColors.mainText.opacity(0.58) : AppColors.border, lineWidth: isSelected ? 2 : 1)

            if isSelected {
                Circle()
                    .fill(AppColors.mainText.opacity(0.72))
                    .frame(width: 22, height: 22)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 17, y: 17)
            }
        }
        .frame(width: 58, height: 58)
        .contentShape(Circle())
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
                    fallbackIcon
                }
            } else if let color = icon.petankoGroupIconColor {
                color
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .background(AppColors.chromeHighlight.opacity(0.78))
        .clipShape(Circle())
        .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
    }

    private var fallbackIcon: some View {
        Image("BootSplashIcon")
            .resizable()
            .scaledToFill()
    }
}

private extension String {
    var petankoGroupIconColor: Color? {
        guard hasPrefix("color:#") else { return nil }
        let hex = String(dropFirst("color:#".count))
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }
}
