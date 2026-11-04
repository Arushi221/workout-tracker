import SwiftUI
import CadenceCore
import CadenceFeatures

struct HomeMuscleMapView: View {
    let dashboard: HomeDashboardState
    let volumeRows: [HomeDashboardState.VolumeRow]?
    @Binding var selectedPanel: MuscleMapPanel
    let onSelect: (MuscleGroup) -> Void
    let onOpenCardio: () -> Void

    private var volumeDict: [MuscleGroup: Double] {
        var dict: [MuscleGroup: Double] = [:]
        for row in (volumeRows ?? dashboard.volume) {
            dict[row.group] = Double(row.sets)
        }
        return dict
    }

    private var rows: [HomeDashboardState.VolumeRow] {
        HomeDashboardPresenter.sortedVolumeRows(volumeRows ?? dashboard.volume)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailedMuscleDiagramView(
                selectedPanel: $selectedPanel,
                volumeData: volumeDict,
                onSelect: onSelect
            )

            let totals = rows.filter(\.isTracked).reduce(0) { $0 + $1.sets }
            let target = rows.filter(\.isTracked).count * 12
            HStack(alignment: .firstTextBaseline) {
                Text("\(WeeklySetProgress.formattedSets(totals))")
                    .font(.title2.weight(.bold)).monospacedDigit()
                Text("/ \(target) sets").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    onOpenCardio()
                } label: {
                    Label("Cardio \(Int(dashboard.cardioDetail.moderateEquivalentMinutes.rounded())) min",
                          systemImage: "heart.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.pink)
            }
        }
        .accessibilityIdentifier("home.week.sets.muscleMap")
    }
}

