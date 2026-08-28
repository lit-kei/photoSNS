import SwiftUI

struct DiaryBackgroundView: View {
    let background: ScrapbookBackground

    var body: some View {
        switch background {
        case .notebook:
            NotebookBackground()
        case .grid:
            GridPaperBackground()
        case .craft:
            PetankoTheme.craft
        case .sky:
            PetankoTheme.sky
        case .pink:
            PetankoTheme.pinkPaper
        case .stars:
            LinearGradient(colors: [Color(red: 0.06, green: 0.09, blue: 0.18), Color(red: 0.16, green: 0.19, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .check:
            CheckBackground()
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
        stride(from: rect.minX, through: rect.maxX, by: cellSize).forEach { x in
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        stride(from: rect.minY, through: rect.maxY, by: cellSize).forEach { y in
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}
