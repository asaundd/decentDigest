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

    var body: some View {
        // A plain List, styled as a page, so news rows can be swiped.
        List {
            header
                .padding(.top, Theme.margin)
                .digestRow()
            ForEach(digest.sectionOrder) { section in
                SectionRule()
                    .digestRow()
                sectionView(section)
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

    @ViewBuilder
    private func sectionView(_ section: DigestSection) -> some View {
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
            NewsSectionView(refresh: refresh)
        case .podcasts:
            DigestSectionView(title: section.title, rows: digest.episodes.filter(\.status.isActive).map { item in
                DigestSectionView.Row(id: item.id, title: item.title, detail: item.sourceName, trailing: item.opensInPanel ? "›" : "↗")
            })
            .digestRow()
        }
    }

    private var footer: some View {
        Text("› reads here  ·  ↗ opens another app")
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
