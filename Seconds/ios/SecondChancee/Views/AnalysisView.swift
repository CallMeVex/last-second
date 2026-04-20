import SwiftUI

struct AnalysisView: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var relapseLogs: [RelapseLog] = []
    @State private var recentCheckins: [DailyCheckin] = []
    @State private var isLoading = true
    @State private var selectedCalendarStreak: StreakTracker?

    private var totalCleanDays: Int {
        appState.streaks.reduce(0) { $0 + $1.totalCleanDays }
    }

    private var totalSavedAmount: Double {
        guard let dailyEstimate = appState.currentUser?.dailySpendingEstimate, dailyEstimate > 0 else { return 0 }

        let moneyTypes = Set(["nicotine", "alcohol"])
        let monetaryStreaks = appState.streaks.filter { moneyTypes.contains($0.addictionType.lowercased()) }
        guard !monetaryStreaks.isEmpty else { return 0 }

        let adjustedDays = monetaryStreaks.reduce(0) { partial, streak in
            partial + max(streak.totalCleanDays - streak.relapseCount, 0)
        }

        // One daily estimate is shared for nicotine/alcohol selections, so avoid double counting.
        let normalizedDays = Double(adjustedDays) / Double(monetaryStreaks.count)
        return max(0, normalizedDays * dailyEstimate)
    }

    private var totalSavedText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter.string(from: NSNumber(value: totalSavedAmount)) ?? "\(totalSavedAmount)"
    }

    private var progressSinceText: String {
        let sorted = appState.streaks.compactMap { $0.lastCheckinDate }.sorted()
        if let first = sorted.first {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: first) {
                let display = DateFormatter()
                display.dateFormat = "MMMM d, yyyy"
                return "Consistent progress since \(display.string(from: date))"
            }
        }
        guard let joinDate = appState.currentUser?.joinDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: joinDate) {
            let display = DateFormatter()
            display.dateFormat = "MMMM d, yyyy"
            return "Journey started \(display.string(from: date))"
        }
        return ""
    }

    private var last7Checkins: [DailyCheckin] {
        let sorted = recentCheckins.sorted { $0.date < $1.date }
        return Array(sorted.suffix(7))
    }

    private func addictionIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "alcohol": return "wineglass"
        case "gambling": return "dollarsign.circle"
        case "nicotine": return "smoke"
        case "pornography": return "eye.slash"
        default: return "circle.dotted"
        }
    }

    private func formatRelapseDate(_ log: RelapseLog) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = formatter.date(from: log.loggedAt ?? "") {
            let display = DateFormatter()
            display.dateFormat = "MMM d"
            return display.string(from: date)
        }
        return ""
    }

    var body: some View {
        ZStack {
            AppTheme.charcoal.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(AppTheme.terracotta)
                    }
                    Spacer()
                    Text("Progress Analysis")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(AppTheme.warmWhite)
                    Spacer()
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if isLoading {
                    Spacer()
                    ProgressView().tint(AppTheme.terracotta)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            TotalRecoveryCard(
                                totalDays: totalCleanDays,
                                sinceText: progressSinceText,
                                totalSavedText: totalSavedText,
                                showTotalSaved: totalSavedAmount > 0
                            )

                            if !appState.streaks.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "flame.fill")
                                            .foregroundStyle(AppTheme.terracotta)
                                        Text("Active Streaks")
                                            .font(.system(.headline, design: .serif))
                                            .foregroundStyle(AppTheme.warmWhite)
                                    }

                                    ForEach(appState.streaks, id: \.id) { streak in
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(AppTheme.terracotta.opacity(0.18))
                                                    .frame(width: 44, height: 44)
                                                Image(systemName: addictionIcon(streak.addictionType))
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(AppTheme.terracotta)
                                            }

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(streak.addictionType.capitalized)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(AppTheme.warmWhite)
                                                Text("Day \(streak.currentStreak)")
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.subtleGray)
                                            }

                                            Spacer()

                                            Button {
                                                selectedCalendarStreak = streak
                                            } label: {
                                                Text("\(streak.currentStreak)d")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(AppTheme.charcoal)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(AppTheme.terracotta)
                                                    .clipShape(.rect(cornerRadius: 20))
                                            }
                                        }
                                        .padding(14)
                                        .background(AppTheme.cardBackground)
                                        .clipShape(.rect(cornerRadius: 12))
                                    }
                                }
                            }

                            if last7Checkins.count > 1 {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Text("Urge Intensity")
                                            .font(.system(.headline, design: .serif))
                                            .foregroundStyle(AppTheme.warmWhite)
                                        Spacer()
                                        Text("LAST 7 DAYS")
                                            .font(.system(size: 10, weight: .semibold))
                                            .tracking(1.2)
                                            .foregroundStyle(AppTheme.subtleGray)
                                    }

                                    SmoothUrgeGraph(checkins: last7Checkins)
                                        .frame(height: 140)

                                    Text("Minimalist view: No axes, just the journey.")
                                        .font(.caption)
                                        .italic()
                                        .foregroundStyle(AppTheme.subtleGray)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }

                            if !relapseLogs.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Learning Moments")
                                            .font(.system(.headline, design: .serif))
                                            .foregroundStyle(AppTheme.warmWhite)
                                        Text("\"Every setback is information, not failure.\"")
                                            .font(.caption)
                                            .italic()
                                            .foregroundStyle(AppTheme.terracotta)
                                    }

                                    VStack(spacing: 2) {
                                        ForEach(relapseLogs.prefix(3)) { log in
                                            LearningMomentRow(log: log, dateText: formatRelapseDate(log))
                                        }

                                        if relapseLogs.count > 3 {
                                            Button {
                                            } label: {
                                                Text("VIEW FULL HISTORY")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .tracking(1.5)
                                                    .foregroundStyle(AppTheme.terracotta)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 16)
                                            }
                                        }
                                    }
                                    .background(AppTheme.cardBackground)
                                    .clipShape(.rect(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .sheet(item: $selectedCalendarStreak) { streak in
            StreakCalendarView(streak: streak, relapseLogs: relapseLogs)
        }
    }

    private func loadData() async {
        guard let userId = appState.currentUser?.id else {
            isLoading = false
            return
        }
        do {
            relapseLogs = try await appState.supabase.fetchRelapseLogs(userId: userId)
            recentCheckins = try await appState.supabase.fetchRecentCheckins(userId: userId, limit: 30)
        } catch {
        }
        isLoading = false
    }
}

struct StreakCalendarView: View {
    let streak: StreakTracker
    let relapseLogs: [RelapseLog]
    @Environment(\.dismiss) private var dismiss

    @State private var displayedMonth = Date()
    private let calendar = Calendar.current

    private var setbackDates: Set<Date> {
        let logsForAddiction = relapseLogs.filter { $0.addictionType.caseInsensitiveCompare(streak.addictionType) == .orderedSame }
        return Set(logsForAddiction.compactMap { log in
            guard let loggedAt = log.loggedAt else { return nil }
            return calendar.startOfDay(for: parseLogDate(loggedAt))
        })
    }

    private var streakDates: Set<Date> {
        guard streak.currentStreak > 0 else { return [] }
        let today = calendar.startOfDay(for: Date())
        return Set((0..<streak.currentStreak).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { calendar.startOfDay(for: $0) }
        })
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.charcoal.ignoresSafeArea()

                VStack(spacing: 16) {
                    HStack {
                        Button {
                            if let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                                displayedMonth = previous
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(AppTheme.terracotta)
                        }

                        Spacer()

                        Text(monthTitle)
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(AppTheme.warmWhite)

                        Spacer()

                        Button {
                            if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                                displayedMonth = next
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.terracotta)
                        }
                    }

                    CalendarMonthGrid(
                        month: displayedMonth,
                        streakDates: streakDates,
                        setbackDates: setbackDates
                    )

                    HStack(spacing: 14) {
                        legendDot(color: .green, text: "Streak day (no setback)")
                        legendDot(color: .red, text: "Setback logged")
                    }
                    .padding(.top, 4)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("\(streak.addictionType.capitalized) Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.subtleGray)
                }
            }
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.subtleGray)
        }
    }

    private func parseLogDate(_ value: String) -> Date {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return date
        }
        return Date()
    }
}

struct CalendarMonthGrid: View {
    let month: Date
    let streakDates: Set<Date>
    let setbackDates: Set<Date>

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var dayHeaders: [String] { ["S", "M", "T", "W", "T", "F", "S"] }

    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let firstWeekday = calendar.dateComponents([.weekday], from: interval.start).weekday else { return [] }
        let leadingEmpty = max(firstWeekday - 1, 0)
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 0
        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: interval.start) {
                days.append(date)
            }
        }
        return days
    }

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(dayHeaders, id: \.self) { header in
                    Text(header)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.subtleGray)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date: date)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }
        }
    }

    private func dayCell(date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let startOfDay = calendar.startOfDay(for: date)
        let hasSetback = setbackDates.contains(startOfDay)
        let isStreakDay = streakDates.contains(startOfDay)
        let background: Color = hasSetback ? .red : (isStreakDay ? .green : AppTheme.cardBackground)

        return Text("\(day)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(hasSetback || isStreakDay ? Color.white : AppTheme.warmWhite)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(background.opacity(hasSetback || isStreakDay ? 0.9 : 1))
            .clipShape(.rect(cornerRadius: 8))
    }
}

struct TotalRecoveryCard: View {
    let totalDays: Int
    let sinceText: String
    let totalSavedText: String
    let showTotalSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Total Recovery Days")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleGray)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(totalDays)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.terracotta)
                Text("days clean")
                    .font(.system(.title3, design: .serif))
                    .italic()
                    .foregroundStyle(AppTheme.terracotta.opacity(0.7))
            }

            if !sinceText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.subtleGray)
                    Text(sinceText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtleGray)
                }
            }

            if showTotalSaved {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.terracotta.opacity(0.9))
                    Text("Total Saved: \(totalSavedText)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.warmWhite)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppTheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
    }
}

struct SmoothUrgeGraph: View {
    let checkins: [DailyCheckin]

    var body: some View {
        GeometryReader { geo in
            let sorted = checkins.sorted { $0.date < $1.date }
            let count = sorted.count
            guard count > 1 else { return AnyView(EmptyView()) }

            let w = geo.size.width
            let h = geo.size.height
            let padding: CGFloat = 20
            let usableW = w - padding * 2
            let usableH = h - padding * 2
            let stepX = usableW / CGFloat(count - 1)

            let points: [CGPoint] = sorted.enumerated().map { index, checkin in
                let x = padding + CGFloat(index) * stepX
                let y = padding + usableH - (CGFloat(checkin.urgeLevel) / 10.0 * usableH)
                return CGPoint(x: x, y: y)
            }

            return AnyView(
                ZStack {
                    smoothPath(points: points, closed: true, fillBottom: h)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.terracotta.opacity(0.25), AppTheme.terracotta.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    smoothPath(points: points, closed: false, fillBottom: h)
                        .stroke(AppTheme.terracotta, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    ForEach(Array(points.enumerated()), id: \.offset) { index, pt in
                        Circle()
                            .fill(AppTheme.terracotta)
                            .frame(width: 8, height: 8)
                            .position(x: pt.x, y: pt.y)
                    }
                }
            )
        }
        .background(Color.clear)
    }

    private func smoothPath(points: [CGPoint], closed: Bool, fillBottom: CGFloat) -> Path {
        guard points.count > 1 else { return Path() }
        var path = Path()

        path.move(to: points[0])
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let cpX = (prev.x + curr.x) / 2
            path.addCurve(
                to: curr,
                control1: CGPoint(x: cpX, y: prev.y),
                control2: CGPoint(x: cpX, y: curr.y)
            )
        }

        if closed {
            if let last = points.last, let first = points.first {
                path.addLine(to: CGPoint(x: last.x, y: fillBottom))
                path.addLine(to: CGPoint(x: first.x, y: fillBottom))
                path.closeSubpath()
            }
        }

        return path
    }
}

struct LearningMomentRow: View {
    let log: RelapseLog
    let dateText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.charcoal.opacity(0.6))
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.subtleGray)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(log.addictionType.capitalized) Setback")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.warmWhite)

                    if let reflection = log.reflection, !reflection.isEmpty {
                        Text(reflection)
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtleGray)
                            .lineSpacing(2)
                            .lineLimit(3)
                    }
                }
                .padding(.leading, 4)

                Spacer()

                if !dateText.isEmpty {
                    Text(dateText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.warmWhite.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.charcoal)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.subtleGray.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 14)
        }
    }
}
