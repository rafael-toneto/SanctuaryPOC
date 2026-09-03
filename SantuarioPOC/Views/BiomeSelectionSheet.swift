import SwiftUI

struct BiomeSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onSelect: (Biome) -> Void

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SanctuaryBackdrop()

                ScrollView {
                    VStack(spacing: 20) {
                        introduction

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Biome.allCases) { biome in
                                BiomeSelectionCard(biome: biome) {
                                    onSelect(biome)
                                    dismiss()
                                }
                            }
                        }

                        Label(
                            "O novo terreno ficará disponível imediatamente para acolher animais compatíveis.",
                            systemImage: "info.circle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            .white.opacity(0.055),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.08))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Escolher bioma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Fechar")
                }
            }
            .toolbarBackground(SanctuaryTheme.ink.opacity(0.94), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var introduction: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(SanctuaryTheme.lime.opacity(0.15))

                Image(systemName: "leaf.fill")
                    .font(.title2.bold())
                    .foregroundStyle(SanctuaryTheme.lime)
            }
            .frame(width: 52, height: 52)
            .overlay(Circle().stroke(SanctuaryTheme.lime.opacity(0.18)))

            SectionHeading(
                eyebrow: "Novo terreno",
                title: "Que vida vai florescer aqui?",
                detail: "Cada bioma acolhe espécies diferentes. Escolha o ambiente que deseja criar no santuário."
            )
        }
    }
}

private struct BiomeSelectionCard: View {
    let biome: Biome
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: biome.symbolName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(.black.opacity(0.18), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.16)))

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(7)
                        .background(.black.opacity(0.14), in: Circle())
                }

                Spacer(minLength: 0)

                Text(biome.mapTitle)
                    .font(.headline.bold())

                Text(biome.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .padding(15)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(biome.gradient)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.18))
            }
            .shadow(color: biome.accentColor.opacity(0.2), radius: 12, y: 6)
        }
        .buttonStyle(BiomeSelectionButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(biome.mapTitle)
        .accessibilityValue(biome.subtitle)
        .accessibilityHint("Cria um terreno deste bioma")
        .accessibilityAddTraits(.isButton)
    }
}

private struct BiomeSelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
