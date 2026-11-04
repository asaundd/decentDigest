import DigestCore
import SwiftUI

/// The main screen: one calm page with every section the user set up.
struct DigestView: View {
    var digest: Digest = SampleDigest.make()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(digest.sectionOrder) { section in
                    SectionRule()
                    sectionView(section)
                }
                SectionRule()
                footer
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, Theme.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Theme.ink)
        .tint(Theme.accent)
        .background(
            LinearGradient(colors: [Theme.pageTintTop, Theme.pageTintBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
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
    }

    @ViewBuilder
    private func sectionView(_ section: DigestSection) -> some View {
        switch section {
        case .weather:
            if let weather = digest.weather { WeatherSectionView(weather: weather) }
        case .calendar:
            DigestSectionView(title: section.title, rows: digest.events.map { event in
                DigestSectionView.Row(id: event.id, leading: event.start.formatted(date: .omitted, time: .shortened), title: event.title, detail: event.calendarName)
            })
        case .todos:
            DigestSectionView(title: section.title, rows: digest.todos.map { todo in
                DigestSectionView.Row(id: todo.id, title: todo.title, detail: todo.listName)
            })
        case .news:
            DigestSectionView(title: section.title, rows: digest.news.filter(\.status.isActive).map { item in
                DigestSectionView.Row(id: item.id, title: item.title, detail: item.sourceName, trailing: item.opensInPanel ? "›" : "↗")
            })
        case .podcasts:
            DigestSectionView(title: section.title, rows: digest.episodes.filter(\.status.isActive).map { item in
                DigestSectionView.Row(id: item.id, title: item.title, detail: item.sourceName, trailing: item.opensInPanel ? "›" : "↗")
            })
        }
    }

    private var footer: some View {
        Text("› reads here  ·  ↗ opens another app")
            .font(.footnote)
            .foregroundStyle(Theme.secondary)
    }
}

#Preview("Light") {
    DigestView()
}

#Preview("Dark") {
    DigestView()
        .preferredColorScheme(.dark)
}
