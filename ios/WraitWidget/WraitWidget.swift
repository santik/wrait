import SwiftUI
import WidgetKit

// Must match the Dart `kWidgetAppGroupId` and the entitlements.
private let appGroupId = "group.com.wrait.flutter"

private enum WidgetKeys {
    static let entryCount = "entryCount"
    static let activeDays = "activeDays"
    static let quotaUsed = "quotaUsed"
    static let quotaLimit = "quotaLimit"
    static let quotaResetAtMs = "quotaResetAtEpochMs"
}

struct WraitEntry: TimelineEntry {
    let date: Date
    let entryCount: Int
    let activeDays: Int
    let quota: WidgetQuotaDisplay.Quota?
}

struct WraitProvider: TimelineProvider {
    func placeholder(in context: Context) -> WraitEntry {
        WraitEntry(date: Date(), entryCount: 0, activeDays: 0, quota: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WraitEntry) -> Void) {
        completion(readEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WraitEntry>) -> Void) {
        let now = Date()
        var entries: [WraitEntry] = [readEntry(at: now)]
        if let resetMs = resetAtMs(), resetMs > now.timeIntervalSince1970 * 1000 {
            entries.append(readEntry(at: Date(timeIntervalSince1970: resetMs / 1000)))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func defaults() -> UserDefaults? { UserDefaults(suiteName: appGroupId) }

    private func resetAtMs() -> Double? {
        guard let d = defaults(), d.object(forKey: WidgetKeys.quotaResetAtMs) != nil else { return nil }
        return d.double(forKey: WidgetKeys.quotaResetAtMs)
    }

    private func readEntry(at date: Date) -> WraitEntry {
        guard let d = defaults() else {
            return WraitEntry(date: date, entryCount: 0, activeDays: 0, quota: nil)
        }
        var quota: WidgetQuotaDisplay.Quota?
        if d.object(forKey: WidgetKeys.quotaLimit) != nil,
           d.object(forKey: WidgetKeys.quotaResetAtMs) != nil {
            quota = WidgetQuotaDisplay.resolve(
                used: d.integer(forKey: WidgetKeys.quotaUsed),
                limit: d.integer(forKey: WidgetKeys.quotaLimit),
                resetAtMs: d.double(forKey: WidgetKeys.quotaResetAtMs),
                nowMs: date.timeIntervalSince1970 * 1000
            )
        }
        return WraitEntry(
            date: date,
            entryCount: d.integer(forKey: WidgetKeys.entryCount),
            activeDays: d.integer(forKey: WidgetKeys.activeDays),
            quota: quota
        )
    }
}

/// wrait brand glyph (speech bubble + waveform), drawn to fill its frame.
struct WraitGlyph: View {
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 108
            let bubble = Path(
                roundedRect: CGRect(x: 29 * s, y: 34 * s, width: 50 * s, height: 34 * s),
                cornerRadius: 9 * s
            )
            ctx.stroke(bubble, with: .color(color), style: StrokeStyle(lineWidth: 4 * s, lineJoin: .round))

            var tail = Path()
            tail.move(to: CGPoint(x: 41 * s, y: 65 * s))
            tail.addLine(to: CGPoint(x: 33 * s, y: 80 * s))
            tail.addLine(to: CGPoint(x: 49 * s, y: 65 * s))
            tail.closeSubpath()
            ctx.fill(tail, with: .color(color))

            let bars: [(CGFloat, CGFloat)] = [
                (34.5, 15), (40.5, 9), (46.5, 4), (52.5, 11), (58.5, 4), (64.5, 9), (70.5, 15),
            ]
            for (x, h) in bars {
                let r = CGRect(x: (x - 1.5) * s, y: (51 - h / 2) * s, width: 3 * s, height: h * s)
                ctx.fill(Path(roundedRect: r, cornerRadius: 1.5 * s), with: .color(color))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct WraitWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WraitEntry

    private var stats: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "wrait")
                .font(.system(size: family == .systemSmall ? 16 : 17, weight: .semibold))
                .foregroundColor(.wraitText)
            Text(WidgetL10n.entries(entry.entryCount))
                .font(.system(size: 13)).foregroundColor(.wraitText).lineLimit(1)
            Text(WidgetL10n.days(entry.activeDays))
                .font(.system(size: 13)).foregroundColor(.wraitText).lineLimit(1)
            if let quota = entry.quota {
                Text(WidgetL10n.quota(used: quota.used, limit: quota.limit))
                    .font(.system(size: 13)).foregroundColor(.wraitMuted).lineLimit(1)
            }
        }
    }

    var body: some View {
        Group {
            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 4) {
                    WraitGlyph(color: .wraitText).frame(width: 46, height: 46)
                    stats
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 10) {
                    WraitGlyph(color: .wraitText).frame(width: 62, height: 62)
                    stats
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .padding(family == .systemSmall ? 12 : 14)
        .widgetContainerBackground(Color.wraitBackground)
        .widgetURL(URL(string: "wrait://record"))
    }
}

struct WraitWidget: Widget {
    let kind: String = "WraitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WraitProvider()) { entry in
            WraitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(Text(verbatim: "wrait"))
        .description(Text(WidgetL10n.description))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct WraitWidgetBundle: WidgetBundle {
    var body: some Widget {
        WraitWidget()
    }
}

// MARK: - Theming (mirrors the app's wrait_colors tokens)

private extension Color {
    static let wraitBackground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.102, green: 0.098, blue: 0.090, alpha: 1)
            : UIColor(red: 0.980, green: 0.976, blue: 0.969, alpha: 1)
    })
    static let wraitText = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.910, green: 0.894, blue: 0.867, alpha: 1)
            : UIColor(red: 0.173, green: 0.169, blue: 0.153, alpha: 1)
    })
    static let wraitMuted = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.659, green: 0.643, blue: 0.627, alpha: 1)
            : UIColor(red: 0.361, green: 0.349, blue: 0.325, alpha: 1)
    })
}

private extension View {
    @ViewBuilder
    func widgetContainerBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
        }
    }
}
