import WidgetKit
import SwiftUI

// ── Constants ─────────────────────────────────────────────────────────────────

private let appGroup = "group.com.example.fengCalendar"
private let purple   = Color(red: 91/255, green: 76/255, blue: 245/255)

// ── Data models ───────────────────────────────────────────────────────────────

struct WidgetEvent: Identifiable {
    let id    = UUID()
    let title : String
    let time  : String?
    let location: String?
}

struct WidgetTodo: Identifiable {
    let id       = UUID()
    let title    : String
    let deadline : String?
    let priority : String
}

struct ScheduleEntry: TimelineEntry {
    let date         : Date
    let todayEvents  : [WidgetEvent]
    let upcomingEvents: [WidgetEvent]
    let pendingTodos : [WidgetTodo]
}

// ── Provider ─────────────────────────────────────────────────────────────────

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: .now, todayEvents: [], upcomingEvents: [], pendingTodos: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let entry     = makeEntry()
        let nextFetch = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextFetch)))
    }

    // ── Parsing ───────────────────────────────────────────────────────────────

    private func makeEntry() -> ScheduleEntry {
        let ud = UserDefaults(suiteName: appGroup)
        return ScheduleEntry(
            date:          .now,
            todayEvents:   parseEvents(ud?.string(forKey: "events_json")   ?? "[]"),
            upcomingEvents: parseEvents(ud?.string(forKey: "upcoming_json") ?? "[]"),
            pendingTodos:  parseTodos( ud?.string(forKey: "todos_json")    ?? "[]")
        )
    }

    private func parseEvents(_ json: String) -> [WidgetEvent] {
        guard let data = json.data(using: .utf8),
              let arr  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return arr.compactMap { d in
            guard let title = d["title"] as? String, !title.isEmpty else { return nil }
            return WidgetEvent(title: title,
                               time: d["time"] as? String,
                               location: d["location"] as? String)
        }
    }

    private func parseTodos(_ json: String) -> [WidgetTodo] {
        guard let data = json.data(using: .utf8),
              let arr  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return arr.compactMap { d in
            guard let title = d["title"] as? String, !title.isEmpty else { return nil }
            return WidgetTodo(title: title,
                              deadline: d["deadline"] as? String,
                              priority: d["priority"] as? String ?? "medium")
        }
    }
}

// ── Shared sub-views ──────────────────────────────────────────────────────────

struct EventRow: View {
    let event: WidgetEvent
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(purple)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption).fontWeight(.semibold)
                    .lineLimit(1)
                if let t = event.time {
                    Text(t)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TodoRow: View {
    let todo: WidgetTodo
    var accentColor: Color {
        switch todo.priority {
        case "high":   return Color(red: 239/255, green: 68/255,  blue: 68/255)
        case "low":    return Color(red: 148/255, green: 163/255, blue: 184/255)
        default:       return Color(red: 249/255, green: 115/255, blue: 22/255)
        }
    }
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .strokeBorder(accentColor, lineWidth: 1.5)
                .frame(width: 10, height: 10)
            Text(todo.title)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct EmptyHint: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ── Widget views ──────────────────────────────────────────────────────────────

// Small: next upcoming event
struct SmallView: View {
    let entry: ScheduleEntry
    var next: WidgetEvent? { entry.upcomingEvents.first }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("日程", systemImage: "calendar")
                .font(.caption2).fontWeight(.bold)
                .foregroundStyle(purple)
            Divider()
            if let e = next {
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.title)
                        .font(.caption).fontWeight(.semibold)
                        .lineLimit(2)
                    if let t = e.time {
                        Label(t, systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let l = e.location {
                        Label(l, systemImage: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            } else {
                EmptyHint(message: "今日无日程")
            }
        }
        .padding(12)
    }
}

// Medium: today events + pending todos side by side
struct MediumView: View {
    let entry: ScheduleEntry
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Events column
            VStack(alignment: .leading, spacing: 4) {
                Label("今日日程", systemImage: "calendar")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(purple)
                Divider()
                if entry.todayEvents.isEmpty {
                    EmptyHint(message: "今日无日程")
                } else {
                    ForEach(entry.todayEvents.prefix(3)) { e in
                        EventRow(event: e)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 6)

            Divider()

            // Todos column
            VStack(alignment: .leading, spacing: 4) {
                Label("待办", systemImage: "checklist")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(Color(red: 249/255, green: 115/255, blue: 22/255))
                Divider()
                if entry.pendingTodos.isEmpty {
                    EmptyHint(message: "没有待办")
                } else {
                    ForEach(entry.pendingTodos.prefix(3)) { t in
                        TodoRow(todo: t)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 6)
        }
        .padding(12)
    }
}

// Large: full list
struct LargeView: View {
    let entry: ScheduleEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("日程 & 待办", systemImage: "calendar.badge.checkmark")
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(purple)
            Divider()

            if !entry.upcomingEvents.isEmpty {
                Text("即将日程").font(.caption2).foregroundStyle(.secondary)
                ForEach(entry.upcomingEvents.prefix(4)) { e in
                    EventRow(event: e)
                }
            }
            if !entry.pendingTodos.isEmpty {
                Text("待办").font(.caption2).foregroundStyle(.secondary)
                ForEach(entry.pendingTodos.prefix(4)) { t in
                    TodoRow(todo: t)
                }
            }
            if entry.upcomingEvents.isEmpty && entry.pendingTodos.isEmpty {
                EmptyHint(message: "没有日程和待办 🎉")
            }
            Spacer()
        }
        .padding(14)
    }
}

// ── Main Widget ───────────────────────────────────────────────────────────────

struct ScheduleWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ScheduleEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        case .systemLarge:  LargeView(entry: entry)
        default:            SmallView(entry: entry)
        }
    }
}

@main
struct ScheduleWidget: Widget {
    let kind = "ScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("枫枫子的备忘录")
        .description("今日日程和待办速览")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
