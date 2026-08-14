import SwiftUI
import UIKit

struct StickerPostScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StickerPostViewModel()

    let originalImage: UIImage
    let stickerPNG: Data
    let draft: StickerDraft
    @State private var selectedGroupIDs: Set<String> = []
    @State private var postedGroups: [PetalogGroup] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let uiImage = UIImage(data: stickerPNG) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 220)
                        .padding(12)
                        .background(AppColors.surface.opacity(0.94))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 0.8)
                        }
                } else {
                    EmptyStateView(systemImage: "exclamationmark.triangle.fill", title: "ステッカー生成待ち", message: "戻ってもう一度「完成」を押してください。")
                }

                ControlSection(title: "投稿するグループ") {
                    if appState.groups.isEmpty {
                        EmptyStateView(systemImage: "person.3.fill", title: "投稿先がありません", message: "先にグループを作るか参加してください。")
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                toggleAllGroups()
                            } label: {
                                HStack {
                                    Text(areAllGroupsSelected ? "すべて解除" : "すべて選択")
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
                                    HStack {
                                        Text(group.icon).font(.title2)
                                        Text(group.name).font(.headline)
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

                Button {
                    Task { await upload() }
                } label: {
                    if viewModel.isUploading {
                        ProgressView("Firebase Storageに保存中")
                    } else {
                        Label(uploadButtonTitle, systemImage: "plus.circle.fill")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(selectedGroupIDs.isEmpty || viewModel.isUploading || stickerPNG.isEmpty)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                ForEach(postedGroups) { group in
                    NavigationLink("\(group.name)の絵日記を見る") {
                        DiaryScreen(group: group)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
            .padding(20)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationTitle("投稿")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedGroupIDs.isEmpty, let firstGroup = appState.groups.first {
                selectedGroupIDs.insert(firstGroup.id)
            }
        }
    }

    private func upload() async {
        guard let user = appState.currentUser else { return }
        let selectedGroups = appState.groups.filter { selectedGroupIDs.contains($0.id) }
        let posts = await viewModel.upload(
            originalImage: originalImage,
            stickerPNG: stickerPNG,
            draft: draft,
            groups: selectedGroups,
            user: user
        )
        let postedGroupIDs = Set(posts.map(\.groupId))
        postedGroups = selectedGroups.filter { postedGroupIDs.contains($0.id) }
    }

    private var uploadButtonTitle: String {
        selectedGroupIDs.count <= 1
            ? "絵日記に追加する"
            : "\(selectedGroupIDs.count)個のグループに追加する"
    }

    private var areAllGroupsSelected: Bool {
        !appState.groups.isEmpty && selectedGroupIDs.count == appState.groups.count
    }

    private func toggleSelection(for group: PetalogGroup) {
        if selectedGroupIDs.contains(group.id) {
            selectedGroupIDs.remove(group.id)
        } else {
            selectedGroupIDs.insert(group.id)
        }
    }

    private func toggleAllGroups() {
        if areAllGroupsSelected {
            selectedGroupIDs.removeAll()
        } else {
            selectedGroupIDs = Set(appState.groups.map(\.id))
        }
    }
}
