import SwiftUI

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
    @State private var inviteCode = ""

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
                                        Text(group.icon).font(.title)
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

                            HStack(spacing: 8) {
                                ForEach(["📘", "🏖", "🎒", "🎪", "🎂", "🎤"], id: \.self) { icon in
                                    Button(icon) { groupIcon = icon }
                                        .font(.title2)
                                        .frame(width: 42, height: 42)
                                        .background(icon == groupIcon ? AppColors.silver.opacity(0.34) : AppColors.surface.opacity(0.94))
                                        .clipShape(Circle())
                                }
                            }

                            Button {
                                Task {
                                    await appState.createGroup(name: groupName, icon: groupIcon)
                                    groupName = ""
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
                            Button {
                                Task {
                                    await appState.joinGroup(inviteCode: inviteCode)
                                    inviteCode = ""
                                }
                            } label: {
                                Label("参加する", systemImage: "qrcode")
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                            .disabled(inviteCode.trimmedForPetalog.isEmpty)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationTitle("グループ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
