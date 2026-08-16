import SwiftUI
import UIKit

struct StickerCreationModeScreen: View {
    let originalImage: UIImage

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 330)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                            .stroke(AppColors.border, lineWidth: 0.8)
                    }

                NavigationLink {
                    StickerCreationScreen(originalImage: originalImage)
                } label: {
                    CreationModeCard(title: "切り抜き")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    BackgroundRemovalStickerScreen(originalImage: originalImage)
                } label: {
                    CreationModeCard(title: "背景透過")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .background { PetalogMetalBackground() }
        .navigationTitle("ステッカーの作り方")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CreationModeCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.mainText)

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.subheadline.bold())
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(16)
        .background(AppColors.surface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }
}
