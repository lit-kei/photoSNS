import SwiftUI
import UIKit

struct StickerPostScreen: View {
    @EnvironmentObject private var appState: AppState

    let stickerPNG: Data
    var originalStickerPNG: Data? = nil
    let draft: StickerDraft
    @State private var selectedGroupIDs: Set<String> = []
    @State private var publishToBlog = true
    @State private var didApplyDefaultDestinations = false
    @State private var didCustomizeDestinations = false
    @State private var submissionError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let uiImage = UIImage(data: stickerPNG) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: min(UIScreen.main.bounds.width * 0.48, 190))
                        .padding(12)
                        .background(AppColors.surface.opacity(0.94))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 0.8)
                        }
                } else {
                    compactNotice(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "ステッカー生成待ち"
                    )
                }

                postingGuidelineMessage

                ControlSection(title: "投稿先") {
                    VStack(spacing: 10) {
                        Button {
                            didCustomizeDestinations = true
                            publishToBlog.toggle()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "text.bubble.fill")
                                    .foregroundStyle(AppColors.burntOrange)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("タイムライン")
                                        .font(.headline)
                                        .foregroundStyle(AppColors.mainText)
                                }
                                Spacer()
                                Image(systemName: publishToBlog ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(publishToBlog ? AppColors.mainText : AppColors.secondaryText)
                            }
                        }
                        .buttonStyle(ListRowButtonStyle())

                        if appState.groups.isEmpty {
                            compactNotice(
                                systemImage: "person.3.fill",
                                title: "グループ投稿先がありません"
                            )
                        } else {
                            Button {
                                toggleAllGroups()
                            } label: {
                                HStack {
                                    Text("グループをすべて選択")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Image(systemName: areAllGroupsSelected ? "checkmark.circle.fill" : "circle")
                                }
                            }
                            .buttonStyle(ListRowButtonStyle())

                            ForEach(appState.groups) { group in
                                Button {
                                    toggleSelection(for: group)
                                } label: {
                                    HStack(spacing: 10) {
                                        GroupIconView(icon: group.icon, iconURL: group.iconURL, imageData: nil, size: 34, fontSize: 18)
                                        Text(group.name)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Spacer()
                                        if selectedGroupIDs.contains(group.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AppColors.mainText)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(AppColors.secondaryText)
                                        }
                                    }
                                }
                                .buttonStyle(ListRowButtonStyle())
                            }
                        }
                    }
                }

                StickerSubmissionControl(
                    networkMonitor: appState.networkMonitor,
                    coordinator: appState.stickerUploadCoordinator,
                    isSelectionValid: (publishToBlog || !selectedGroupIDs.isEmpty) && !stickerPNG.isEmpty,
                    title: "投稿",
                    onSubmit: submit
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background {
            PetankoMetalBackground()
        }
        .navigationTitle("投稿")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            applyDefaultDestinationsIfNeeded()
        }
        .onChange(of: appState.groups) { _, _ in
            applyDefaultDestinationsIfNeeded()
        }
        .alert("投稿を開始できません", isPresented: Binding(
            get: { submissionError != nil },
            set: { if !$0 { submissionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(submissionError ?? "")
        }
    }

    private func compactNotice(systemImage: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
        .background(AppColors.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
                .stroke(AppColors.border.opacity(0.8), lineWidth: 0.8)
        }
    }

    private var postingGuidelineMessage: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.accentPink)
                .padding(.top, 1)

            Text("他人を傷つける内容、権利侵害、性的・暴力的な画像、個人情報を含む投稿は禁止です。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }

    private func submit() {
        guard let user = appState.currentUser else {
            submissionError = "ログイン情報を確認できません。"
            return
        }
        let selectedGroups = appState.groups.filter { selectedGroupIDs.contains($0.id) }
        let error = appState.stickerUploadCoordinator.submit(
            stickerPNG: stickerPNG,
            originalStickerPNG: originalStickerPNG,
            draft: draft,
            groups: selectedGroups,
            publishToBlog: publishToBlog,
            user: user
        )
        if let error {
            submissionError = error
        } else {
            appState.selectedTab = .home
        }
    }


    private var areAllGroupsSelected: Bool {
        !appState.groups.isEmpty && selectedGroupIDs.count == appState.groups.count
    }

    private func applyDefaultDestinationsIfNeeded() {
        guard !didApplyDefaultDestinations, !didCustomizeDestinations else { return }
        publishToBlog = true
        guard !appState.groups.isEmpty else { return }
        selectedGroupIDs = Set(appState.groups.map(\.id))
        didApplyDefaultDestinations = true
    }

    private func toggleSelection(for group: PetankoGroup) {
        didCustomizeDestinations = true
        if selectedGroupIDs.contains(group.id) {
            selectedGroupIDs.remove(group.id)
        } else {
            selectedGroupIDs.insert(group.id)
        }
    }

    private func toggleAllGroups() {
        didCustomizeDestinations = true
        if areAllGroupsSelected {
            selectedGroupIDs.removeAll()
        } else {
            selectedGroupIDs = Set(appState.groups.map(\.id))
        }
    }

}

private struct StickerSubmissionControl: View {
    @ObservedObject var networkMonitor: NetworkMonitor
    @ObservedObject var coordinator: StickerUploadCoordinator
    let isSelectionValid: Bool
    let title: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            Button(action: onSubmit) {
                Label(title, systemImage: "plus.circle.fill")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!isSelectionValid || networkMonitor.status != .online || coordinator.state.isRunning)
            .opacity(isSelectionValid ? 1.0 : 0.5)

            if let message = statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(networkMonitor.status == .offline ? .red : AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var statusMessage: String? {
        if coordinator.state.isRunning {
            return "別の投稿を保存しています。"
        }
        switch networkMonitor.status {
        case .checking:
            return "通信状態を確認しています…"
        case .offline:
            return "インターネット接続がないため投稿できません。"
        case .online:
            return nil
        }
    }
}
