import SwiftUI

struct PanelView: View {
    @ObservedObject var store: Store
    let chooseFolder: () -> Void
    let resetPosition: () -> Void
    @ObservedObject private var theme = ThemeStore.shared

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]

    init(store: Store, chooseFolder: @escaping () -> Void, resetPosition: @escaping () -> Void) {
        self.store = store
        self.chooseFolder = chooseFolder
        self.resetPosition = resetPosition
    }

    var body: some View {
        VStack(spacing: 0) {
            WindowDrag(onDoubleClick: resetPosition)
                .frame(height: 16)
                .overlay {
                    Capsule().fill(theme.palette.text.opacity(0.25))
                        .frame(width: 36, height: 4)
                        .allowsHitTesting(false)
                }
            if store.shots.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(store.shots) { Tile(shot: $0, store: store) }
                    }
                    .padding(10)
                }
            }
            if !store.selection.isEmpty || store.status != nil {
                Divider()
                footer
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 260, maxHeight: .infinity)
        .foregroundStyle(theme.palette.text)
        .tint(theme.palette.accent)
        .background(theme.palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
                .accessibilityHidden(true)
            Text("No screenshots yet").font(.headline)
            Text("New images in \((store.folder.path as NSString).abbreviatingWithTildeInPath) appear here.")
                .font(.caption).multilineTextAlignment(.center)
            Button("Choose Folder…") { chooseFolder() }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if !store.selection.isEmpty {
                Button("Clear") { store.clearSelection() }
            }
            Spacer()
            if let status = store.status {
                Text(status).font(.caption).lineLimit(2)
            }
            Spacer()
            if !store.selection.isEmpty {
                Button("Delete", role: .destructive) { store.trashSelection() }
            }
        }
        .padding(10)
        .background(WindowDrag())
    }
}
