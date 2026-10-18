import SwiftUI
import SwiftData
import CadenceCore
import CadenceFeatures

/// Root Plan tab: the user's scheduled workouts laid out day by day (today and
/// the next six days), each expandable to its exercises × sets × reps. Starting
/// hands off to Today, which owns the workout editor and the live session; the
/// projection logic lives in `PlanTabPresenter`.
struct PlanTabView: View {
    /// Switches to the Today tab before a start request is posted.
    let onStartHandoff: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: [SortDescriptor(\ScheduledWorkout.scheduledDate),
                  SortDescriptor(\ScheduledWorkout.title)])
    private var records: [ScheduledWorkout]
    @State private var workouts: [PlanTabPresenter.Workout] = []
    @State private var expanded: Set<UUID> = []
    @State private var rescheduleRecord: ScheduledWorkout?
    @State private var deleteRecord: ScheduledWorkout?
    @State private var failedStartRecordID: UUID?

    private struct ProjectionKey: Equatable {
        let records: [ScheduledWorkoutTaskSignature]
        let unit: MeasurementUnitPreference
    }

    private var projectionKey: ProjectionKey {
        ProjectionKey(records: records.map {
            ScheduledWorkoutTaskSignature(id: $0.id,
                                          scheduledDate: $0.scheduledDate,
                                          updatedAt: $0.updatedAt,
                                          statusRaw: $0.statusRaw,
                                          payloadVersion: $0.payloadVersion)
        }, unit: settings.unit)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(PlanTabPresenter.days(workouts)) { day in
                    Section {
                        if day.workouts.isEmpty {
                            Text("Nothing planned")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(day.workouts) { workoutRow($0) }
                        }
                    } header: {
                        dayHeader(day)
                    }
                }
                let later = PlanTabPresenter.later(workouts)
                if !later.isEmpty {
                    Section("Later") { ForEach(later) { workoutRow($0, showsDate: true) } }
                }
                let overdue = PlanTabPresenter.overdue(workouts)
                if !overdue.isEmpty {
                    Section("Missed") { ForEach(overdue) { workoutRow($0, showsDate: true) } }
                }
                Section {
                    Text("This tab shows the workouts you've scheduled. To add one, build a workout and choose Schedule. Starting a workout opens it on Today, where you can still change it before you begin.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Plan")
            .task(id: projectionKey) { await project() }
            .sheet(item: $rescheduleRecord) { record in
                ScheduleWorkoutSheet(title: record.title) { date in
                    _ = try ScheduledWorkoutStore.reschedule(recordID: record.id, to: date, in: context)
                }
            }
            .confirmationDialog("Delete this planned workout?",
                                isPresented: Binding(get: { deleteRecord != nil },
                                                     set: { if !$0 { deleteRecord = nil } }),
                                titleVisibility: .visible,
                                presenting: deleteRecord) { record in
                Button("Delete \(record.title)", role: .destructive) {
                    _ = try? ScheduledWorkoutStore.cancel(recordID: record.id, in: context)
                }
            } message: { _ in
                Text("It's removed from your plan. Workouts you've already logged aren't affected.")
            }
            .alert("Couldn't open this workout", isPresented: Binding(
                get: { failedStartRecordID != nil },
                set: { if !$0 { failedStartRecordID = nil } })) {
                    Button("Try Again") {
                        if let id = failedStartRecordID, let record = record(id) { start(record) }
                    }
                    Button("Close", role: .cancel) { failedStartRecordID = nil }
                } message: {
                    Text("The saved workout could not be read. Try again, or reschedule or delete it from this list if the problem continues.")
                }
        }
    }

    private func dayHeader(_ day: PlanTabPresenter.Day) -> some View {
        HStack {
            Text(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
            if day.isToday {
                Text("Today")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.teal)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func workoutRow(_ workout: PlanTabPresenter.Workout, showsDate: Bool = false) -> some View {
        if let record = record(workout.id) {
            let isExpanded = expanded.contains(workout.id)
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation { toggle(workout.id) }
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.item.title).font(.headline)
                            Text(summary(workout, showsDate: showsDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if workout.item.status == .started {
                            Text("IN PROGRESS")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.teal)
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(isExpanded ? Text("Hides the exercises") : Text("Shows the exercises"))

                if isExpanded, case .strength(let lines) = workout.content {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(line.name).font(.subheadline.weight(.medium))
                            Text(line.setsLine).font(.caption).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                HStack {
                    Button(workout.item.status == .started ? "Resume" : "Start") { start(record) }
                        .buttonStyle(.borderedProminent)
                    Button("Reschedule") { rescheduleRecord = record }
                        .buttonStyle(.bordered)
                    Button("Delete", role: .destructive) { deleteRecord = record }
                        .buttonStyle(.bordered)
                }
                .font(.subheadline)
            }
            .padding(.vertical, 4)
            .accessibilityIdentifier("planTab.workout.\(workout.id.uuidString)")
        }
    }

    private func summary(_ workout: PlanTabPresenter.Workout, showsDate: Bool) -> String {
        var parts: [String] = []
        if showsDate { parts.append(workout.item.date.formatted(date: .abbreviated, time: .omitted)) }
        if ScheduledWorkoutDate.hasExplicitTime(workout.item.date) {
            parts.append(workout.item.date.formatted(date: .omitted, time: .shortened))
        }
        switch workout.content {
        case .strength(let lines):
            parts.append(String(localized: "Exercises: \(lines.count) · Sets: \(workout.totalSets)"))
        case .cardio(let type):
            parts.append(type.displayName)
        case .unreadable:
            parts.append(String(localized: "Workout plan"))
        }
        return parts.joined(separator: " · ")
    }

    private func record(_ id: UUID) -> ScheduledWorkout? {
        records.first { $0.id == id }
    }

    private func toggle(_ id: UUID) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    private func start(_ record: ScheduledWorkout) {
        guard let request = ScheduledWorkoutStartRouter.request(for: record) else {
            failedStartRecordID = record.id
            return
        }
        failedStartRecordID = nil
        onStartHandoff()
        ScheduledWorkoutStartRouter.post(request)
    }

    private func project() async {
        let inputs = records.map {
            (row: HomePlannedWorkoutsSection.rowInput($0), item: HomePlannedWorkoutsSection.item($0))
        }
        let unit = settings.unit
        let projected = await Task.detached(priority: .utility) {
            inputs.map {
                PlanTabPresenter.workout(item: $0.item,
                                         payloadData: $0.row.payloadData,
                                         payloadVersion: $0.row.payloadVersion,
                                         unit: unit)
            }
        }.value
        guard !Task.isCancelled else { return }
        workouts = projected
    }
}
