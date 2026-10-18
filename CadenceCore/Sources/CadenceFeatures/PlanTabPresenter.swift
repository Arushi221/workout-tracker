import Foundation
import CadenceCore

/// Day-by-day projection of scheduled workouts for the Plan tab: today plus the
/// following days, each with its planned workouts and a per-exercise
/// sets × reps breakdown. Value-only, so the tab projects it off the main actor
/// exactly like `PlannedWorkoutsListView` does.
public enum PlanTabPresenter {
    public static let defaultDayCount = 7

    /// One planned movement: `Bench Press` · 3 sets · `60 kg×8  ·  60 kg×8  ·  60 kg×8`.
    public struct ExerciseLine: Equatable, Sendable {
        public let name: String
        public let setCount: Int
        public let setsLine: String

        public init(name: String, setCount: Int, setsLine: String) {
            self.name = name
            self.setCount = setCount
            self.setsLine = setsLine
        }
    }

    public enum Content: Equatable, Sendable {
        case strength([ExerciseLine])
        case cardio(CardioType)
        /// The stored payload could not be decoded; the row still offers
        /// reschedule/delete so the user can recover.
        case unreadable
    }

    public struct Workout: Identifiable, Equatable, Sendable {
        public let item: PlannedWorkoutsPresenter.Item
        public let content: Content
        public var id: UUID { item.id }

        public init(item: PlannedWorkoutsPresenter.Item, content: Content) {
            self.item = item
            self.content = content
        }

        public var totalSets: Int {
            guard case .strength(let lines) = content else { return 0 }
            return lines.reduce(0) { $0 + $1.setCount }
        }
    }

    public struct Day: Identifiable, Equatable, Sendable {
        /// Start of the calendar day.
        public let date: Date
        public let isToday: Bool
        public let workouts: [Workout]
        public var id: Date { date }
    }

    /// Decodes one scheduled record's payload into its display content.
    public static func workout(item: PlannedWorkoutsPresenter.Item,
                               payloadData: Data,
                               payloadVersion: Int,
                               unit: MeasurementUnitPreference) -> Workout {
        if let cardio = try? ScheduledWorkoutStore.decodeCardioType(payloadData, version: payloadVersion) {
            return Workout(item: item, content: .cardio(cardio))
        }
        guard let plan = try? ScheduledWorkoutStore.decode(payloadData, version: payloadVersion) else {
            return Workout(item: item, content: .unreadable)
        }
        return Workout(item: item, content: .strength(exerciseLines(plan, unit: unit)))
    }

    /// The user's own sets for each exercise (partners' plans stay on the
    /// workout editor, which the Start button opens).
    public static func exerciseLines(_ plan: EditablePlan,
                                     unit: MeasurementUnitPreference) -> [ExerciseLine] {
        plan.exercises.map { exercise in
            let sets = exercise.performerPlans.first(where: \.isMe)?.sets ?? exercise.sets
            return ExerciseLine(
                name: exercise.name,
                setCount: sets.count,
                setsLine: PlanFormatting.setsLine(sets,
                                                  isBodyweight: ExerciseLoading.isBodyweight(named: exercise.name),
                                                  unit: unit))
        }
    }

    /// Today and the following `count - 1` days, every day present even when
    /// nothing is planned so the week reads as a calendar.
    public static func days(_ workouts: [Workout],
                            now: Date = Date(),
                            calendar: Calendar = .current,
                            count: Int = defaultDayCount) -> [Day] {
        let start = calendar.startOfDay(for: now)
        let upcoming = ordered(workouts, PlannedWorkoutsPresenter.todayAndFuture(
            workouts.map(\.item), now: now, calendar: calendar))
        return (0..<max(count, 0)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return Day(date: day,
                       isToday: offset == 0,
                       workouts: upcoming.filter { calendar.isDate($0.item.date, inSameDayAs: day) })
        }
    }

    /// Planned workouts after the day window, so nothing scheduled is hidden.
    public static func later(_ workouts: [Workout],
                             now: Date = Date(),
                             calendar: Calendar = .current,
                             count: Int = defaultDayCount) -> [Workout] {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: max(count, 0), to: start) else { return [] }
        return ordered(workouts, PlannedWorkoutsPresenter.todayAndFuture(
            workouts.map(\.item), now: now, calendar: calendar))
            .filter { $0.item.date >= end }
    }

    /// Planned workouts from earlier days that were never started or finished.
    public static func overdue(_ workouts: [Workout],
                               now: Date = Date(),
                               calendar: Calendar = .current) -> [Workout] {
        ordered(workouts, PlannedWorkoutsPresenter.overdue(workouts.map(\.item), now: now, calendar: calendar))
    }

    /// Re-attaches content to the presenter's filtered, ordered items.
    private static func ordered(_ workouts: [Workout],
                                _ items: [PlannedWorkoutsPresenter.Item]) -> [Workout] {
        let byID = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return items.compactMap { byID[$0.id] }
    }
}
