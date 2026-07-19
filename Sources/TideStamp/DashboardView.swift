import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var settingsStore: ReminderSettingsStore
    @ObservedObject var achievementStore: AchievementStore
    let onDateSelected: (Date) -> Void
    let onCloseButtonClicked: () -> Void

    @State private var displayedYear = Calendar.current.component(.year, from: Date())

    private let calendar = Calendar.current
    // Keep the calendar readable by preserving month/day order, while tighter
    // spacing makes the rewards feel more like a clustered field.
    private let dayColumns = Array(
        repeating: GridItem(.flexible(minimum: 15), spacing: 4), count: 31)
    private let monthLabelWidth: CGFloat = 10
    private let rewardMarkerSize: CGFloat = 26
    private let rewardMarkerSlotSize: CGFloat = 26

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
        VStack(alignment: .leading, spacing: 8) {
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
            // Overlay the close control so it does not increase the dashboard
            // header height or add extra margin above the reward grid.
            .overlay(alignment: .trailing) {
                Button(action: onCloseButtonClicked) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: 22)
                .help("Close")
            }

            clusteredRewardGrid
                .padding(.vertical, 2)
                // Keep the reward grid directly below the year controls. Since daily
                // details now live in a separate popover, centering this flexible area
                // creates an unwanted gap under the dashboard close button.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // Match main's left inset so the dashboard content opens at its original
        // horizontal position, while keeping extra breathing room elsewhere.
        .padding(.top, 6)
        .padding(.horizontal, 1)
        .padding(.trailing, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .preferredColorScheme(.light)
        .font(AppFont.body)
    }

    private var clusteredRewardGrid: some View {
        HStack(alignment: .top, spacing: 3) {
            VStack(alignment: .center, spacing: 1) {
                ForEach(monthsInDisplayedYear, id: \.month) { month in
                    Text("\(month.month)")
                        .font(AppFont.monthLabel)
                        .foregroundStyle(.secondary)
                        .frame(width: monthLabelWidth, alignment: .center)
                        .frame(height: rewardMarkerSlotSize)
                }
            }
            .padding(.top, 3)
            .offset(x: -4)

            VStack(alignment: .leading, spacing: 1) {
                ForEach(monthsInDisplayedYear, id: \.month) { month in
                    LazyVGrid(columns: dayColumns, alignment: .leading, spacing: 4) {
                        ForEach(month.days, id: \.self) { date in
                            Button {
                                // AppDelegate owns the detached detail popover,
                                // so the dashboard only reports the clicked reward.
                                onDateSelected(date)
                            } label: {
                                dayMarker(for: date)
                            }
                            .buttonStyle(.plain)
                            .help(date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                    .frame(height: rewardMarkerSlotSize)
                }
            }
            .padding(.top, 3)
            .padding(.leading, 1)
            .padding(.trailing, 6)
            .padding(.bottom, 6)
            // Keep the ordered reward grid on a clean white field.
            .background(Color.white)
        }
    }

    @ViewBuilder
    private func dayMarker(for date: Date) -> some View {
        let padding = markerPadding(for: date)
        let offset = markerOffset(for: date)
        let scale = markerScale(for: date)

        if let rewardImage = Self.todayRewardImage {
            Image(nsImage: rewardImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                // The fixed outer slot keeps every calendar cell stable while the
                // scale/padding/offset gives the repeated reward art variation.
                .frame(width: rewardMarkerSize, height: rewardMarkerSize)
                .scaleEffect(scale)
                .padding(padding)
                .offset(x: offset.width, y: offset.height)
                .frame(width: rewardMarkerSlotSize, height: rewardMarkerSlotSize)
        } else {
            // Fallback keeps the calendar visible if the reward asset is missing.
            Circle()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: rewardMarkerSize, height: rewardMarkerSize)
                .scaleEffect(scale)
                .padding(padding)
                .offset(x: offset.width, y: offset.height)
                .frame(width: rewardMarkerSlotSize, height: rewardMarkerSlotSize)
        }
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

    private func markerScale(for date: Date) -> CGFloat {
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)

        // Deterministic size variation keeps the yearly rewards organic without
        // changing each cell's outer layout slot.
        let variants: [CGFloat] = [0.94, 0.98, 1.0, 1.03, 1.06]
        return variants[(day + month) % variants.count]
    }

    private var firstDayOfDisplayedYear: Date {
        calendar.date(from: DateComponents(year: displayedYear, month: 1, day: 1)) ?? Date()
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
}

final class DailyDetailSelectionStore: ObservableObject {
    // Keep the daily detail popover's hosting controller stable while clicks
    // update only the selected date rendered inside that existing popover.
    @Published var selectedDate = Date()
}

struct DailyDetailView: View {
    @ObservedObject var achievementStore: AchievementStore
    @ObservedObject var selectionStore: DailyDetailSelectionStore
    let onCloseButtonClicked: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selectionStore.selectedDate.formatted(date: .complete, time: .omitted))
                    .font(AppFont.headline)

                Spacer()

                Button(action: onCloseButtonClicked) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close")
            }

            let items = achievementStore.trackedItemsWithProgress(on: selectionStore.selectedDate)

            if items.isEmpty {
                Text("No reminder items")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(items) { item in
                            HStack {
                                Text(item.title)
                                    .lineLimit(1)

                                Spacer()

                                Text(progressText(for: item, on: selectionStore.selectedDate))
                                    .font(AppFont.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .scrollIndicators(.visible)
            }
        }
        // This view lives in its own popover, so its background fills the whole
        // separate block below the main home view.
        .padding()
        .background(Color(red: 0xFA / 255, green: 0xFA / 255, blue: 0xFA / 255))
        .frame(width: 280, height: 220)
        .preferredColorScheme(.light)
        .font(AppFont.body)
    }

    private func progressText(for item: TrackedReminderItem, on selectedDate: Date) -> String {
        let progress = achievementStore.progress(for: item, on: selectedDate)
        return "\(progress.completed)/\(progress.released)"
    }
}

private struct MonthDays {
    let month: Int
    let days: [Date]
}
