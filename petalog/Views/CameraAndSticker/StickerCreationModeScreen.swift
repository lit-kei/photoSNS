import SwiftUI
import UIKit

struct StickerCreationModeScreen: View {
    let originalImage: UIImage

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.section) {
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

                VStack(spacing: 0) {
                    NavigationLink {
                        StickerCreationScreen(originalImage: originalImage)
                    } label: {
                        CreationModeRow(
                            title: "切り抜き",
                            detail: "",
                            systemImage: "scissors"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        BackgroundRemovalStickerScreen(originalImage: originalImage)
                    } label: {
                        CreationModeRow(
                            title: "背景透過",
                            detail: "",
                            systemImage: "person.crop.rectangle"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop)
            .padding(.bottom, 30)
        }
        .background { PetalogMetalBackground() }
        .navigationTitle("ステッカーの作り方")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CreationModeRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
                .frame(width: 46, height: 46)
                .background(AppColors.chromeHighlight.opacity(0.78), in: Circle())
                .overlay {
                    Circle().stroke(AppColors.border, lineWidth: 0.8)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.darkSilver)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 0.8)
        }
    }
}
