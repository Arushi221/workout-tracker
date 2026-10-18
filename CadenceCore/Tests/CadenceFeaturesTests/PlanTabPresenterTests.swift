import XCTest
import CadenceCore
@testable import CadenceFeatures

final class PlanTabPresenterTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Friday 2026-10-16 09:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_792_141_200)

    private func date(dayOffset: Int, hour: Int = 12) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .hour, value: dayOffset * 24 + hour, to: start)!
    }

    private func workout(_ title: String, dayOffset: Int,
                         status: ScheduledWorkoutStatus = .scheduled,
                         content: PlanTabPresenter.Content = .unreadable) -> PlanTabPresenter.Workout {
        PlanTabPresenter.Workout(
            item: PlannedWorkoutsPresenter.Item(id: UUID(), date: date(dayOffset: dayOffset),
                                                title: title, detail: "", status: status),
            content: content)
    }

    func testDaysCoverTodayAndFollowingSixDaysIncludingEmptyOnes() {
        let days = PlanTabPresenter.days([], now: now, calendar: calendar)

        XCTAssertEqual(days.count, 7)
        XCTAssertTrue(days[0].isToday)
        XCTAssertFalse(days[1...].contains(where: \.isToday))
        XCTAssertEqual(days[0].date, calendar.startOfDay(for: now))
        XCTAssertEqual(days[6].date, calendar.date(byAdding: .day, value: 6, to: calendar.startOfDay(for: now)))
        XCTAssertTrue(days.allSatisfy { $0.workouts.isEmpty })
    }

    func testWorkoutsLandOnTheirDayAndHiddenStatusesAreDropped() {
        let push = workout("Push", dayOffset: 0)
        let legs = workout("Legs", dayOffset: 2)
        let done = workout("Done", dayOffset: 2, status: .completed)
        let cancelled = workout("Cancelled", dayOffset: 3, status: .cancelled)

        let days = PlanTabPresenter.days([legs, push, done, cancelled], now: now, calendar: calendar)

        XCTAssertEqual(days[0].workouts.map(\.item.title), ["Push"])
        XCTAssertEqual(days[2].workouts.map(\.item.title), ["Legs"])
        XCTAssertTrue(days[3].workouts.isEmpty)
    }

    func testLaterAndOverdueKeepEverythingOutsideTheWindowVisible() {
        let past = workout("Missed", dayOffset: -1)
        let inWindow = workout("Sunday", dayOffset: 6)
        let afterWindow = workout("Next week", dayOffset: 7)

        let all = [past, inWindow, afterWindow]
        XCTAssertEqual(PlanTabPresenter.later(all, now: now, calendar: calendar).map(\.item.title), ["Next week"])
        XCTAssertEqual(PlanTabPresenter.overdue(all, now: now, calendar: calendar).map(\.item.title), ["Missed"])
        XCTAssertEqual(PlanTabPresenter.days(all, now: now, calendar: calendar)[6].workouts.map(\.item.title), ["Sunday"])
    }

    func testStrengthPayloadDecodesToPerExerciseSetLines() throws {
        let plan = EditablePlan(
            title: "Upper",
            warmupMinutes: 5,
            cooldownMinutes: 5,
            exercises: [
                EditableExercise(name: "Bench Press",
                                 sets: [EditableSet(targetReps: 8, targetWeight: 60),
                                        EditableSet(targetReps: 6, targetWeight: 65)],
                                 notes: ""),
                EditableExercise(name: "Push-up",
                                 sets: [EditableSet(targetReps: 12, targetWeight: nil)],
                                 notes: "")
            ])
        let payload = try ScheduledWorkoutStore.encode(plan)
        let version = ScheduledWorkoutStore.currentPayloadVersion
        let item = PlannedWorkoutsPresenter.Item(id: UUID(), date: now, title: "Upper",
                                                 detail: "", status: .scheduled)

        let decoded = PlanTabPresenter.workout(item: item, payloadData: payload,
                                               payloadVersion: version, unit: .kilograms)

        guard case .strength(let lines) = decoded.content else {
            return XCTFail("expected strength content, got \(decoded.content)")
        }
        XCTAssertEqual(lines.map(\.name), ["Bench Press", "Push-up"])
        XCTAssertEqual(lines.map(\.setCount), [2, 1])
        XCTAssertEqual(decoded.totalSets, 3)
        XCTAssertEqual(lines[0].setsLine,
                       PlanFormatting.setsLine(plan.exercises[0].sets, isBodyweight: false, unit: .kilograms))
    }

    func testCorruptPayloadIsUnreadableRatherThanDropped() {
        let item = PlannedWorkoutsPresenter.Item(id: UUID(), date: now, title: "Broken",
                                                 detail: "", status: .scheduled)
        let decoded = PlanTabPresenter.workout(item: item, payloadData: Data("nope".utf8),
                                               payloadVersion: 1, unit: .kilograms)
        XCTAssertEqual(decoded.content, .unreadable)
        XCTAssertEqual(PlanTabPresenter.days([decoded], now: now, calendar: calendar)[0].workouts.count, 1)
    }
}
