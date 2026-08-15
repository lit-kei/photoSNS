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

                VStack(alignment: .leading, spacing: 6) {
                    Text("作り方を選んでください")
                        .font(.title3.bold())
                        .foregroundStyle(AppColors.mainText)
                    Text("切り抜き方や飾りを選んで仕上げられます。")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink {
                    StickerCreationScreen(originalImage: originalImage)
                } label: {
                    CreationModeCard(
                        title: "切り抜き",
                        description: "丸・ハート・花などのフレームで写真を切り抜きます",
                        systemImage: "scissors",
                        accent: AppColors.charcoal
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    BackgroundRemovalStickerScreen(originalImage: originalImage)
                } label: {
                    CreationModeCard(
                        title: "背景透過",
                        description: "人物や物を自動で見つけて、背景だけを透明にします",
                        systemImage: "person.crop.rectangle.badge.sparkles",
                        accent: AppColors.darkSilver
                    )
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
    let description: String
    let systemImage: String
    let accent: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(accent.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.mainText)
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
