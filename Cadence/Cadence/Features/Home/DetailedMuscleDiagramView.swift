import SwiftUI
import CadenceCore

struct DetailedMuscleDiagramView: View {
    @Binding var selectedPanel: MuscleMapPanel
    let volumeData: [MuscleGroup: Double]
    let onSelect: (MuscleGroup) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Picker("Muscle view", selection: $selectedPanel) {
                Text("Front").tag(MuscleMapPanel.front)
                Text("Back").tag(MuscleMapPanel.back)
            }
            .pickerStyle(.segmented)

            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color.white]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if selectedPanel == .front {
                            frontMuscleDiagram
                        } else {
                            backMuscleDiagram
                        }
                    }
                    .padding()
                }
            }
        }
    }

    @ViewBuilder
    private var frontMuscleDiagram: some View {
        VStack(alignment: .center, spacing: 8) {
            // Head & Neck
            muscleButton("Neck", group: .traps, size: .small)

            // Chest & Front Shoulders
            HStack(spacing: 8) {
                muscleButton("Chest", group: .chest, size: .large)
                VStack(spacing: 4) {
                    muscleButton("Front Δ", group: .shoulders, size: .medium)
                    muscleButton("Biceps", group: .biceps, size: .medium)
                }
            }

            // Core
            VStack(spacing: 4) {
                muscleButton("Abs", group: .abdominals, size: .large)
                muscleButton("Obliques", group: .abdominals, size: .medium)
            }

            // Legs
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    muscleButton("Quads", group: .quadriceps, size: .large)
                    muscleButton("Adductors", group: .adductors, size: .medium)
                    muscleButton("Tibialis", group: .tibialis, size: .small)
                }
                VStack(spacing: 4) {
                    muscleButton("Hip Flex", group: .hip_flexors, size: .medium)
                    muscleButton("Calves", group: .calves, size: .medium)
                }
            }

            // Forearms & Wrists
            muscleButton("Forearms", group: .forearms, size: .medium)
        }
    }

    @ViewBuilder
    private var backMuscleDiagram: some View {
        VStack(alignment: .center, spacing: 8) {
            // Upper Back
            HStack(spacing: 8) {
                muscleButton("Traps", group: .traps, size: .large)
                VStack(spacing: 4) {
                    muscleButton("Rear Δ", group: .shoulders, size: .medium)
                    muscleButton("Rhomboids", group: .middle_back, size: .medium)
                }
            }

            // Lats & Back
            VStack(spacing: 4) {
                muscleButton("Lats", group: .lats, size: .large)
                muscleButton("Lower Back", group: .lower_back, size: .medium)
            }

            // Posterior Chain
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    muscleButton("Glutes", group: .glutes, size: .large)
                    muscleButton("Hamstrings", group: .hamstrings, size: .large)
                    muscleButton("Calves", group: .calves, size: .medium)
                }
                VStack(spacing: 4) {
                    muscleButton("Triceps", group: .triceps, size: .large)
                    muscleButton("Forearms", group: .forearms, size: .medium)
                }
            }
        }
    }

    @ViewBuilder
    private func muscleButton(_ label: String, group: MuscleGroup, size: Size) -> some View {
        let sets = volumeData[group] ?? 0
        let level = MuscleHeatPresenter.level(sets: Int(sets), target: 12)
        let bgColor = muscleColor(for: level)

        Button(action: { onSelect(group) }) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                Text("\(Int(sets))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(bgColor.opacity(0.15))
            .border(bgColor, width: 1.5)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .frame(height: sizeHeight(size))
    }

    private func sizeHeight(_ size: Size) -> CGFloat {
        switch size {
        case .small: return 50
        case .medium: return 60
        case .large: return 80
        }
    }

    private func muscleColor(for level: HeatLevel) -> Color {
        switch level {
        case .none: return CadenceTheme.muscleZero
        case .low: return CadenceTheme.muscleBelow
        case .mid, .high: return CadenceTheme.muscleBuilding
        case .onTarget: return CadenceTheme.muscleProductive
        }
    }

    enum Size {
        case small, medium, large
    }
}
