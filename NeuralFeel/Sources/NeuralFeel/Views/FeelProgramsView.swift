import SwiftUI

struct FeelProgramsView: View {
    @State private var selectedProgram: FeelProgram?

    var body: some View {
        NavigationStack {
            List(FeelProgram.all) { program in
                Button { selectedProgram = program } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(program.accentColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: program.icon)
                                .font(.title3)
                                .foregroundStyle(program.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(program.name).font(.headline)
                            Text(program.subtitle).font(.caption).foregroundStyle(.secondary)
                            Text(program.description)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(program.accentColor.opacity(0.05))
            }
            .navigationTitle("Feel Programs")
            .sheet(item: $selectedProgram) { program in
                ActiveSessionView(program: program)
            }
        }
    }
}
