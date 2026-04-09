import SwiftUI

/// List of all available feel programs. Tapping one launches the active session.
struct FeelProgramsView: View {
    @State private var selectedProgram: FeelProgram?

    var body: some View {
        List(FeelProgram.all) { program in
            Button {
                selectedProgram = program
            } label: {
                programRow(program)
            }
            .listRowBackground(program.accentColor.opacity(0.12))
        }
        .navigationTitle("Feel Programs")
        .sheet(item: $selectedProgram) { program in
            ActiveSessionView(program: program)
        }
    }

    private func programRow(_ program: FeelProgram) -> some View {
        HStack(spacing: 10) {
            Image(systemName: program.icon)
                .font(.title3)
                .foregroundStyle(program.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .font(.headline)
                Text(program.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
