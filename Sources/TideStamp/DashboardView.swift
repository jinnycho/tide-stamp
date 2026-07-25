import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var achievementStore: AchievementStore
    @ObservedObject var presentationState: PopoverPresentationState
    let onRewardClicked: (Date) -> Void

    @State private var displayedYear = Calendar.current.component(.year, from: Date())
    @State private var visibleMarkerIDs: Set<String> = []
    @State private var markerAnimationRunID = UUID()

    private let calendar = Calendar.current
    // Flexible columns use the full dashboard width so the reward markers spread
    // out when the popover gets wider instead of staying packed to the left.
    private let dayColumns = Array(
        repeating: GridItem(.flexible(minimum: 16), spacing: 0), count: 31)
    private let monthLabelWidth: CGFloat = 10
    private let rewardMarkerSize: CGFloat = 19
    private let rewardMarkerSlotSize: CGFloat = 20
    private let markerDiagonalRevealDelay: TimeInterval = 0.018

    // SwiftPM flattens processed resource paths here, so reward1.png is loaded
    // from the bundle root even though the source file lives in Assets/rewards.
    // Keep the original 1024px artwork intact and let SwiftUI downsample it.
    private static let todayRewardImage: NSImage? = {
        guard
            let url = Bundle.module.url(
                forResource: "reward1",
                withExtension: "png"
            )
        else { return nil }

        return NSImage(contentsOf: url)
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Keep the year controls compact so the dashboard reads as a calendar
            // first, rather than giving the navigation row the whole popover width.
            HStack(spacing: 8) {
                Button {
                    displayedYear -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: 22)

                Text(String(displayedYear))
                    .font(AppFont.headline)
                    .frame(width: 46)

                Button {
                    displayedYear += 1
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: 22)
            }
            .frame(maxWidth: .infinity)

            // Tight horizontal columns let each row show all 31 reward images
            // while leaving more of the popover's visual weight in the calendar.
            VStack(alignment: .leading, spacing: 8) {
                ForEach(monthsInDisplayedYear, id: \.month) { month in
                    HStack(spacing: 2) {
                        Text("\(month.month)")
                            .font(AppFont.monthLabel)
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(width: monthLabelWidth, alignment: .trailing)

                        LazyVGrid(columns: dayColumns, alignment: .leading, spacing: 6) {
                            ForEach(month.days, id: \.self) { date in
                                Button {
                                    // Date selection now belongs to AppDelegate because
                                    // details are shown in their own popover below Home.
                                    onRewardClicked(date)
                                } label: {
                                    dayMarker(for: date)
                                }
                                .buttonStyle(.plain)
                                .help(date.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            // Keep the reward calendar centered in the dashboard's fixed popover.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .padding(.top, 6)
        .padding(.horizontal, 6)
        .padding(.bottom, 10)
        .font(AppFont.body)
        .background(AppColors.dashboardBackground)
        .foregroundStyle(AppColors.primaryText)
        .preferredColorScheme(.light)
        .onAppear {
            animateCalendarMarkers()
        }
        .onChange(of: displayedYear) { _ in
            animateCalendarMarkers()
        }
        .onChange(of: presentationState.dashboardAnimationToken) { _ in
            animateCalendarMarkers()
        }
    }

    @ViewBuilder
    private func dayMarker(for date: Date) -> some View {
        let padding = markerPadding(for: date)
        let offset = markerOffset(for: date)
        let markerID = markerID(for: date)
        let isVisible = visibleMarkerIDs.contains(markerID)
        let isToday = calendar.isDateInToday(date)

        if achievementStore.earnedReward(on: date), let rewardImage = Self.todayRewardImage {
            Image(nsImage: rewardImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                // The fixed outer slot keeps every calendar cell stable while the
                // inner padding/offset gives the repeated reward art variation.
                .frame(width: rewardMarkerSize, height: rewardMarkerSize)
                .padding(padding)
                .offset(x: offset.width, y: offset.height)
                .frame(width: rewardMarkerSlotSize, height: rewardMarkerSlotSize)
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.35)
        } else {
            // Dates that are not earned yet still show as small dots so the
            // calendar remains readable without implying a reward was achieved.
            Circle()
                .fill(isToday ? Color.red : Color.secondary.opacity(0.35))
                .frame(width: 4, height: 4)
                .frame(width: rewardMarkerSlotSize, height: rewardMarkerSlotSize)
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.35)
        }
    }

    private func animateCalendarMarkers() {
        let runID = UUID()
        markerAnimationRunID = runID
        visibleMarkerIDs = []

        // Reveal cells in diagonal bands from top-left to bottom-right. This
        // keeps the calendar lively while still finishing quickly when opened.
        for date in allDisplayedDates {
            DispatchQueue.main.asyncAfter(deadline: .now() + markerRevealDelay(for: date)) {
                guard markerAnimationRunID == runID else {
                    return
                }

                withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                    _ = visibleMarkerIDs.insert(markerID(for: date))
                }
            }
        }
    }

    private func markerRevealDelay(for date: Date) -> TimeInterval {
        let components = calendar.dateComponents([.month, .day], from: date)
        let monthIndex = max((components.month ?? 1) - 1, 0)
        let dayIndex = max((components.day ?? 1) - 1, 0)

        return Double(monthIndex + dayIndex) * markerDiagonalRevealDelay
    }

    private func markerID(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func markerPadding(for date: Date) -> EdgeInsets {
        let day = calendar.component(.day, from: date)

        // Vary the inner spacing by day number so the repeated reward image feels
        // less like a perfectly stamped grid, but remains deterministic.
        return EdgeInsets(
            top: CGFloat(day % 3),
            leading: CGFloat((day + 1) % 3),
            bottom: CGFloat((day + 2) % 3),
            trailing: CGFloat((day + 3) % 3)
        )
    }

    private func markerOffset(for date: Date) -> CGSize {
        let day = calendar.component(.day, from: date)

        return CGSize(
            width: CGFloat((day % 3) - 1) * 0.6,
            height: CGFloat(((day / 2) % 3) - 1) * 0.6
        )
    }

    private var monthsInDisplayedYear: [MonthDays] {
        (1...12).map { month in
            let start =
                calendar.date(from: DateComponents(year: displayedYear, month: month, day: 1))
                ?? Date()
            let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
            let days = range.compactMap { day in
                calendar.date(from: DateComponents(year: displayedYear, month: month, day: day))
            }

            return MonthDays(
                month: month,
                days: days
            )
        }
    }

    private var allDisplayedDates: [Date] {
        monthsInDisplayedYear.flatMap(\.days)
    }
}

private struct MonthDays {
    let month: Int
    let days: [Date]
}

struct DailyDetailsView: View {
    @ObservedObject var achievementStore: AchievementStore
    let selectedDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(AppFont.headline)

            let items = achievementStore.trackedItemsWithProgress(on: selectedDate)

            if items.isEmpty {
                Text("No completed reminders")
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // The details panel is the same size as Home, so long days scroll
                // inside this view instead of resizing the popover.
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.title)
                                    .lineLimit(1)

                                Spacer(minLength: 8)

                                Text(progressText(for: item))
                                    .font(AppFont.body)
                                    .foregroundStyle(AppColors.secondaryText)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.visible)
            }
        }
        .padding()
        .font(AppFont.body)
        .background(AppColors.panelBackground)
        .foregroundStyle(AppColors.primaryText)
        .preferredColorScheme(.light)
    }

    private func progressText(for item: TrackedReminderItem) -> String {
        let progress = achievementStore.progress(for: item, on: selectedDate)
        return "\(progress.completed)/\(progress.released)"
    }
}
