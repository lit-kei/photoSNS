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
    let initialMode: Mode
    @State private var groupName = ""
    @State private var groupIcon = "📘"
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var selectedIconData: Data?
    @State private var inviteCode = ""
    @State private var candidateGroup: PetalogGroup?
    @State private var lookupTask: Task<Void, Never>?
    @State private var isJoining = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if initialMode != .join {
                    ControlSection(title: "所属グループ") {
                        if appState.groups.isEmpty {
                            EmptyStateView(systemImage: "person.3.fill", title: "グループなし", message: "作成すると招待コードが生成されます。")
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
                                        Text("絵文字も下から選べます")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.secondaryText)
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
                                    await appState.createGroup(name: groupName, icon: groupIcon, iconImageData: selectedIconData)
                                    groupName = ""
                                    selectedIconData = nil
                                    selectedIconItem = nil
                                }
                            } label: {
                                Label("グループを作る", systemImage: "person.badge.plus")
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(groupName.trimmedForPetalog.isEmpty)
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
                                    Label("参加する", systemImage: "qrcode")
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                            .disabled(inviteCode.trimmedForPetalog.isEmpty || isJoining)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, AppSpacing.floatingTabClearance)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationTitle("グループ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scheduleLookup(for code: String) {
        lookupTask?.cancel()
        candidateGroup = nil

        let trimmedCode = code.trimmedForPetalog.uppercased()
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
    let group: PetalogGroup
    @State private var groupName: String
    @State private var groupIcon: String
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var selectedIconData: Data?
    @State private var isSaving = false

    init(group: PetalogGroup) {
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
                            .tint(.white)
                    } else {
                        Label("保存する", systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(groupName.trimmedForPetalog.isEmpty || isSaving)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, AppSpacing.floatingTabClearance)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GroupCandidateCard: View {
    let group: PetalogGroup

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
            } else if let iconURL, let url = URL(string: iconURL), !iconURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Text(icon)
                            .font(.system(size: fontSize))
                    }
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
