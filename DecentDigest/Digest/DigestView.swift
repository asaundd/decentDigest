import DigestCore
import SwiftData
import SwiftUI

/// The main screen: one calm page with every section the user set up.
struct DigestView: View {
    /// Weather, calendar, to-dos and podcasts still come from sample data.
    var digest: Digest = SampleDigest.make()
    /// Fetches news. `true` means the reader pulled to refresh.
    var refresh: @Sendable (Bool) async -> Void = { _ in }

    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \SavedItem.savedAt, order: .reverse) private var saved: [SavedItem]
    @State private var panel: PanelRequest?
    /// Where the visible list ends on screen.
    @State private var listBottom: CGFloat = .infinity

    var body: some View {
        // A plain List, styled as a page, so news rows can be swiped.
        ScrollViewReader { proxy in
            List {
                header
                    .padding(.top, Theme.margin)
                    .digestRow()
                ForEach(digest.sectionOrder) { section in
                    // Saved news appears only once something is saved.
                    if section != .savedNews || !saved.isEmpty {
                        SectionRule()
                            .digestRow()
                        sectionView(section) { id, bottom in reveal(id, bottom: bottom, with: proxy) }
                    }
                }
                SectionRule()
                    .digestRow()
                footer
                    .padding(.bottom, Theme.margin)
                    .digestRow()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
            .background(
                LinearGradient(colors: [Theme.pageTintTop, Theme.pageTintBottom], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).maxY
            } action: { bottom in
                listBottom = bottom
            }
        }
        .blur(radius: panel == nil ? 0 : 2)
        .overlay { ArticlePanelHost(panel: $panel) }
        .refreshable { [refresh] in await refresh(true) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { [refresh] in await refresh(false) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Decent Digest")
                .font(Theme.wordmarkFont)
                .foregroundStyle(Theme.secondary)
            Text(digest.date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(Theme.dateFont)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Scrolls an expanded row up only when its bottom is hidden, so rows higher on the screen stay put.
    private func reveal(_ id: String, bottom: CGFloat, with proxy: ScrollViewProxy) {
        guard bottom > listBottom - 8 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    @ViewBuilder
    private func sectionView(_ section: DigestSection, reveal: @escaping (String, CGFloat) -> Void) -> some View {
        switch section {
        case .weather:
            if let weather = digest.weather {
                WeatherSectionView(weather: weather)
                    .digestRow()
            }
        case .calendar:
            DigestSectionView(title: section.title, rows: digest.events.map { event in
                DigestSectionView.Row(id: event.id, leading: event.start.formatted(date: .omitted, time: .shortened), title: event.title, detail: event.calendarName)
            })
            .digestRow()
        case .todos:
            DigestSectionView(title: section.title, rows: digest.todos.map { todo in
                DigestSectionView.Row(id: todo.id, title: todo.title, detail: todo.listName)
            })
            .digestRow()
        case .news:
            NewsSectionView(refresh: refresh, panel: $panel, reveal: reveal)
        case .savedNews:
            SavedNewsSectionView(saved: saved, panel: $panel, reveal: reveal)
        case .podcasts:
            DigestSectionView(title: section.title, rows: digest.episodes.filter(\.status.isActive).map { item in
                DigestSectionView.Row(id: item.id, title: item.title, detail: item.sourceName, trailing: item.opensInPanel ? nil : "↗")
            })
            .digestRow()
        }
    }

    private var footer: some View {
        Text("↗ the feed sends only a title; it opens the site")
            .font(.footnote)
            .foregroundStyle(Theme.secondary)
    }
}

extension View {
    /// Makes a List row look like part of the page: margins only, no separators or background.
    func digestRow() -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: Theme.margin, bottom: 0, trailing: Theme.margin))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview("Light") {
    DigestView()
        .modelContainer(DigestStore.previewContainer())
}

#Preview("Dark") {
    DigestView()
        .modelContainer(DigestStore.previewContainer())
        .preferredColorScheme(.dark)
}
