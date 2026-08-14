import SwiftUI
import UIKit

struct StickerPostScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StickerPostViewModel()

    let originalImage: UIImage
    let stickerPNG: Data
    let draft: StickerDraft
    @State private var selectedGroup: PetalogGroup?
    @State private var postedGroup: PetalogGroup?
    @State private var didPost = false

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
                            ForEach(appState.groups) { group in
                                Button {
                                    selectedGroup = group
                                } label: {
                                    HStack {
                                        Text(group.icon).font(.title2)
                                        Text(group.name).font(.headline)
                                        Spacer()
                                        if selectedGroup?.id == group.id {
                                            Image(systemName: "checkmark.circle")
                                                .foregroundStyle(AppColors.mainText)
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
                        Label("絵日記に追加する", systemImage: "plus.circle.fill")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(selectedGroup == nil || viewModel.isUploading || stickerPNG.isEmpty)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let postedGroup, didPost {
                    NavigationLink("今日の絵日記を見る") {
                        DiaryScreen(group: postedGroup)
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
            selectedGroup = selectedGroup ?? appState.groups.first
        }
    }

    private func upload() async {
        guard let user = appState.currentUser, let group = selectedGroup else { return }
        let post = await viewModel.upload(originalImage: originalImage, stickerPNG: stickerPNG, draft: draft, group: group, user: user)
        if post != nil {
            postedGroup = group
            didPost = true
        }
    }
}
