//
//  ContentView.swift
//  petalog
//
//  Created by 敬祐 on 2026/08/14.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        PetalogRootView()
    }
}

private struct PetalogRootView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeScreen()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            CameraScreen()
                .tabItem {
                    Label("カメラ", systemImage: "camera.fill")
                }
                .tag(AppTab.camera)

            MemoriesScreen()
                .tabItem {
                    Label("思い出", systemImage: "book.pages.fill")
                }
                .tag(AppTab.memories)

            ProfileScreen()
                .tabItem {
                    Label("プロフィール", systemImage: "person.crop.circle.fill")
                }
                .tag(AppTab.profile)
        }
        .tint(PetalogTheme.primary)
    }
}

private enum AppTab {
    case home
    case camera
    case memories
    case profile
}

private struct HomeScreen: View {
    private let groups = SampleData.groups

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(todayText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PetalogTheme.secondaryText)

                        Text("今日の思い出をつくろう")
                            .font(.largeTitle.bold())
                            .foregroundStyle(PetalogTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    NavigationLink {
                        CameraScreen()
                    } label: {
                        Label("写真を撮る", systemImage: "camera.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    HStack(spacing: 12) {
                        NavigationLink {
                            GroupManagementScreen(initialMode: .create)
                        } label: {
                            Label("グループを作る", systemImage: "person.3.fill")
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        NavigationLink {
                            GroupManagementScreen(initialMode: .join)
                        } label: {
                            Label("参加する", systemImage: "qrcode.viewfinder")
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("今日のグループ")
                            .font(.title2.bold())
                            .foregroundStyle(PetalogTheme.text)

                        ForEach(groups) { group in
                            NavigationLink {
                                DiaryScreen(group: group)
                            } label: {
                                GroupActivityCard(group: group)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(PetalogTheme.background)
            .navigationTitle("petalog")
            .toolbar {
                NavigationLink {
                    GroupManagementScreen(initialMode: .list)
                } label: {
                    Image(systemName: "person.2.badge.gearshape.fill")
                }
                .accessibilityLabel("グループ管理")
            }
        }
    }

    private var todayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }
}

private struct GroupActivityCard: View {
    let group: MemoryGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(PetalogTheme.text)

                    Text("\(group.todayStickerCount)枚のステッカー")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PetalogTheme.primary)
                }

                Spacer()

                MemberAvatarStack(members: group.members)
            }

            DiaryCanvasPreview(stickers: group.todayStickers, background: .notebook, compact: true)
                .frame(height: 170)
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PetalogTheme.border, lineWidth: 1)
        }
    }
}

private struct CameraScreen: View {
    @State private var hasCapturedPhoto = false
    @State private var usesFrontCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PetalogTheme.cameraGradient)

                    if hasCapturedPhoto {
                        CapturedPhotoMock()
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: usesFrontCamera ? "person.crop.square.fill" : "camera.viewfinder")
                                .font(.system(size: 58, weight: .semibold))
                            Text(usesFrontCamera ? "前面カメラ" : "背面カメラ")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    Button {
                        usesFrontCamera.toggle()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(CameraIconButtonStyle())
                    .padding(14)
                }

                if hasCapturedPhoto {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                hasCapturedPhoto = false
                            } label: {
                                Label("撮り直す", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(SecondaryActionButtonStyle())

                            NavigationLink {
                                StickerCreationScreen()
                            } label: {
                                Label("ステッカーを作る", systemImage: "scissors")
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                        }
                    }
                } else {
                    Button {
                        hasCapturedPhoto = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 74, height: 74)
                            Circle()
                                .stroke(PetalogTheme.primary, lineWidth: 5)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .accessibilityLabel("撮影")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(PetalogTheme.background)
            .navigationTitle("カメラ")
        }
    }
}

private struct StickerCreationScreen: View {
    @State private var selectedShape: StickerShapeOption = .circle
    @State private var selectedDecoration: StickerDecoration = .sparkle
    @State private var stickerScale = 1.0
    @State private var stickerRotation = -7.0

    private var previewSticker: ScrapbookSticker {
        ScrapbookSticker(
            title: "できたてステッカー",
            author: SampleData.users[0],
            comment: "今日の一枚",
            shape: selectedShape,
            decoration: selectedDecoration,
            tint: .teal,
            symbolName: "figure.2.and.child.holdinghands",
            offset: .zero,
            rotation: stickerRotation,
            scale: stickerScale
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PetalogTheme.photoGradient)

                    StickerPreview(sticker: previewSticker, size: 220, showsAuthor: false)
                        .rotationEffect(.degrees(stickerRotation))
                        .scaleEffect(stickerScale)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)

                ControlSection(title: "切り抜き") {
                    HorizontalOptionPicker(options: StickerShapeOption.allCases, selection: $selectedShape)
                }

                ControlSection(title: "デコレーション") {
                    HorizontalOptionPicker(options: StickerDecoration.allCases, selection: $selectedDecoration)
                }

                ControlSection(title: "フレーム") {
                    VStack(spacing: 14) {
                        SliderRow(title: "サイズ", value: $stickerScale, range: 0.7...1.35)
                        SliderRow(title: "回転", value: $stickerRotation, range: -22...22)
                    }
                }

                NavigationLink {
                    StickerPostScreen(sticker: previewSticker)
                } label: {
                    Label("完成", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
            .padding(20)
        }
        .background(PetalogTheme.background)
        .navigationTitle("ステッカー作成")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StickerPostScreen: View {
    let sticker: ScrapbookSticker
    @State private var selectedGroup = SampleData.groups[0]
    @State private var comment = "海きれいだった！"

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                StickerPreview(sticker: sticker, size: 220, showsAuthor: false)

                ControlSection(title: "投稿するグループ") {
                    VStack(spacing: 10) {
                        ForEach(SampleData.groups) { group in
                            Button {
                                selectedGroup = group
                            } label: {
                                HStack {
                                    Text(group.icon)
                                        .font(.title2)
                                    Text(group.name)
                                        .font(.headline)
                                    Spacer()
                                    if selectedGroup.id == group.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(PetalogTheme.primary)
                                    }
                                }
                            }
                            .buttonStyle(ListRowButtonStyle())
                        }
                    }
                }

                ControlSection(title: "コメント") {
                    TextField("短いコメント", text: $comment)
                        .textFieldStyle(.roundedBorder)
                }

                NavigationLink {
                    DiaryScreen(group: selectedGroup)
                } label: {
                    Label("絵日記に追加する", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
            .padding(20)
        }
        .background(PetalogTheme.background)
        .navigationTitle("投稿")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DiaryScreen: View {
    let group: MemoryGroup
    @State private var selectedSticker: ScrapbookSticker?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("8月14日")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PetalogTheme.secondaryText)
                    Text(group.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(PetalogTheme.text)
                    MemberAvatarStack(members: group.members)
                }

                DiaryCanvasPreview(
                    stickers: group.todayStickers,
                    background: .notebook,
                    compact: false,
                    selectedSticker: $selectedSticker
                )
                .frame(height: 520)

                NavigationLink {
                    DiaryEditorScreen(group: group)
                } label: {
                    Label("絵日記を編集", systemImage: "pencil.and.outline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            .padding(20)
        }
        .background(PetalogTheme.background)
        .navigationTitle("今日の絵日記")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSticker) { sticker in
            StickerDetailSheet(sticker: sticker)
                .presentationDetents([.medium])
        }
    }
}

private struct DiaryEditorScreen: View {
    let group: MemoryGroup
    @State private var selectedBackground: ScrapbookBackground = .notebook
    @State private var title = "8/14 海に行った！"

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                TextField("タイトル", text: $title)
                    .font(.title3.weight(.bold))
                    .textFieldStyle(.roundedBorder)

                DiaryCanvasPreview(stickers: group.todayStickers, background: selectedBackground, compact: false)
                    .frame(height: 480)
                    .overlay(alignment: .topLeading) {
                        Text(title)
                            .font(.title3.bold())
                            .foregroundStyle(PetalogTheme.text)
                            .padding(18)
                    }

                ControlSection(title: "背景") {
                    HorizontalOptionPicker(options: ScrapbookBackground.allCases, selection: $selectedBackground)
                }

                ControlSection(title: "スタンプ") {
                    HStack(spacing: 10) {
                        ForEach(["★", "♥", "!!", "→", "✦", "☺"], id: \.self) { stamp in
                            Text(stamp)
                                .font(.title3.bold())
                                .frame(width: 44, height: 44)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(PetalogTheme.border, lineWidth: 1)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .background(PetalogTheme.background)
        .navigationTitle("絵日記編集")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MemoriesScreen: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("1日1枚の絵日記")
                        .font(.largeTitle.bold())
                        .foregroundStyle(PetalogTheme.text)

                    ForEach(SampleData.memories) { memory in
                        NavigationLink {
                            DiaryScreen(group: memory.group)
                        } label: {
                            MemoryCard(memory: memory)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(PetalogTheme.background)
            .navigationTitle("思い出")
        }
    }
}

private struct MemoryCard: View {
    let memory: DiaryMemory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiaryCanvasPreview(stickers: memory.group.todayStickers, background: memory.background, compact: true)
                .frame(height: 150)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title)
                        .font(.headline)
                        .foregroundStyle(PetalogTheme.text)
                    Text(memory.dateLabel)
                        .font(.subheadline)
                        .foregroundStyle(PetalogTheme.secondaryText)
                }

                Spacer()

                Button {
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("画像として保存")
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PetalogTheme.border, lineWidth: 1)
        }
    }
}

private struct GroupManagementScreen: View {
    enum Mode {
        case list
        case create
        case join
    }

    let initialMode: Mode
    @State private var groupName = ""
    @State private var inviteCode = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if initialMode != .join {
                    ControlSection(title: "所属グループ") {
                        VStack(spacing: 10) {
                            ForEach(SampleData.groups) { group in
                                HStack(spacing: 12) {
                                    Text(group.icon)
                                        .font(.title)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.name)
                                            .font(.headline)
                                        Text("\(group.members.count)人 / \(group.diaryCount)枚の絵日記")
                                            .font(.subheadline)
                                            .foregroundStyle(PetalogTheme.secondaryText)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }

                if initialMode != .join {
                    ControlSection(title: "グループを作る") {
                        VStack(spacing: 12) {
                            TextField("グループ名", text: $groupName)
                                .textFieldStyle(.roundedBorder)
                            Button {
                            } label: {
                                Label("招待コードを生成", systemImage: "person.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                        }
                    }
                }

                if initialMode != .create {
                    ControlSection(title: "グループに参加する") {
                        VStack(spacing: 12) {
                            TextField("招待コード", text: $inviteCode)
                                .textFieldStyle(.roundedBorder)
                            Button {
                            } label: {
                                Label("参加する", systemImage: "qrcode")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(PetalogTheme.background)
        .navigationTitle("グループ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileScreen: View {
    private let user = SampleData.users[0]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        Text(user.avatar)
                            .font(.system(size: 72))
                            .frame(width: 104, height: 104)
                            .background(.white)
                            .clipShape(Circle())
                            .overlay {
                                Circle().stroke(PetalogTheme.border, lineWidth: 1)
                            }

                        Text(user.name)
                            .font(.title.bold())
                            .foregroundStyle(PetalogTheme.text)

                        HStack(spacing: 12) {
                            ProfileStat(title: "グループ", value: "3")
                            ProfileStat(title: "ステッカー", value: "24")
                            ProfileStat(title: "絵日記", value: "11")
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("作ったステッカー")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                            ForEach(SampleData.profileStickers) { sticker in
                                StickerPreview(sticker: sticker, size: 96, showsAuthor: false)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PetalogTheme.background)
            .navigationTitle("プロフィール")
        }
    }
}

private struct ProfileStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(PetalogTheme.text)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PetalogTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DiaryCanvasPreview: View {
    let stickers: [ScrapbookSticker]
    let background: ScrapbookBackground
    var compact = false
    var selectedSticker: Binding<ScrapbookSticker?>?

    var body: some View {
        ZStack {
            backgroundView

            ForEach(stickers) { sticker in
                Button {
                    selectedSticker?.wrappedValue = sticker
                } label: {
                    StickerPreview(sticker: sticker, size: compact ? 72 : 116, showsAuthor: !compact)
                }
                .buttonStyle(.plain)
                .scaleEffect(sticker.scale)
                .rotationEffect(.degrees(sticker.rotation))
                .offset(compact ? sticker.offset.scaled(by: 0.55) : sticker.offset)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PetalogTheme.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch background {
        case .notebook:
            NotebookBackground()
        case .grid:
            GridPaperBackground()
        case .craft:
            PetalogTheme.craft
        case .sky:
            PetalogTheme.sky
        case .pink:
            PetalogTheme.pinkPaper
        case .stars:
            PetalogTheme.night
        case .check:
            CheckBackground()
        }
    }
}

private struct StickerDetailSheet: View {
    let sticker: ScrapbookSticker

    var body: some View {
        VStack(spacing: 18) {
            StickerPreview(sticker: sticker, size: 180, showsAuthor: false)

            VStack(alignment: .leading, spacing: 8) {
                Label(sticker.author.name, systemImage: "person.crop.circle.fill")
                Label(sticker.comment, systemImage: "bubble.left.fill")
                Label("元の写真", systemImage: "photo.fill")
            }
            .font(.headline)
            .foregroundStyle(PetalogTheme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
    }
}

private struct MemberAvatarStack: View {
    let members: [StudentUser]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(members.prefix(4))) { member in
                Text(member.avatar)
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background(.white)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.white, lineWidth: 2)
                    }
                    .accessibilityLabel(member.name)
            }
        }
    }
}

private struct ControlSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(PetalogTheme.text)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HorizontalOptionPicker<Option: PetalogOption>: View {
    let options: [Option]
    @Binding var selection: Option

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options) { option in
                    Button {
                        selection = option
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: option.systemImage)
                                .font(.title3)
                            Text(option.title)
                                .font(.caption.weight(.semibold))
                        }
                        .frame(width: 76, height: 70)
                    }
                    .buttonStyle(OptionButtonStyle(isSelected: option.id == selection.id))
                }
            }
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 48, alignment: .leading)
            Slider(value: $value, in: range)
        }
    }
}

private struct CapturedPhotoMock: View {
    var body: some View {
        ZStack {
            PetalogTheme.photoGradient
            VStack(spacing: 12) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 62))
                Text("今日の写真")
                    .font(.title2.bold())
            }
            .foregroundStyle(.white)
        }
    }
}

private struct NotebookBackground: View {
    var body: some View {
        ZStack {
            Color.white
            VStack(spacing: 24) {
                ForEach(0..<18, id: \.self) { _ in
                    Rectangle()
                        .fill(Color(red: 0.88, green: 0.93, blue: 0.98))
                        .frame(height: 1)
                }
            }
            .padding(.vertical, 16)
        }
    }
}

private struct GridPaperBackground: View {
    var body: some View {
        ZStack {
            Color.white
            GridPattern()
                .stroke(Color(red: 0.88, green: 0.92, blue: 0.95), lineWidth: 1)
        }
    }
}

private struct CheckBackground: View {
    var body: some View {
        ZStack {
            Color(red: 1.0, green: 0.97, blue: 0.98)
            GridPattern(cellSize: 36)
                .stroke(Color(red: 0.98, green: 0.72, blue: 0.78).opacity(0.55), lineWidth: 12)
        }
    }
}

private struct GridPattern: Shape {
    var cellSize: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += cellSize
        }

        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += cellSize
        }
        return path
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(PetalogTheme.primary.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(PetalogTheme.text)
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PetalogTheme.border, lineWidth: 1)
            }
    }
}

private struct CameraIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(.black.opacity(configuration.isPressed ? 0.35 : 0.22))
            .clipShape(Circle())
    }
}

private struct ListRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(PetalogTheme.text)
            .padding(12)
            .background(.white.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PetalogTheme.border, lineWidth: 1)
            }
    }
}

private struct OptionButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .white : PetalogTheme.text)
            .background(isSelected ? PetalogTheme.primary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? PetalogTheme.primary : PetalogTheme.border, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private extension CGSize {
    func scaled(by multiplier: CGFloat) -> CGSize {
        CGSize(width: width * multiplier, height: height * multiplier)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
