import SwiftUI

private struct Pebble: Identifiable {
    let id = UUID()
    var offset: CGSize
    var rotation: Double
    var color: Color
    var width: CGFloat
    var height: CGFloat
}

struct PebbleStackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode

    @State private var pebbles: [Pebble] = []
    @State private var draggingId: UUID? = nil
    @State private var startOffsets: [UUID: CGSize] = [:]

    private let pebbleColors: [Color] = [
        AppTheme.terracotta.opacity(0.7),
        AppTheme.warmWhite.opacity(0.15),
        AppTheme.subtleGray.opacity(0.5),
        AppTheme.terracotta.opacity(0.4),
        AppTheme.warmWhite.opacity(0.1),
    ]

    var body: some View {
        ZStack {
            AppTheme.charcoal.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        // Works when presented modally; also safe when pushed.
                        presentationMode.wrappedValue.dismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(AppTheme.subtleGray)
                    }

                    Spacer()

                    Text("Pebble Stack")
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(AppTheme.warmWhite.opacity(0.7))

                    Spacer()

                    Button("Reset") { generatePebbles() }
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtleGray)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                Text("Move the stones around. Just breathe.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleGray)
                    .padding(.bottom, 16)

                // Canvas
                ZStack {
                    ForEach($pebbles) { $pebble in
                        Ellipse()
                            .fill(pebble.color)
                            .frame(width: pebble.width, height: pebble.height)
                            .rotationEffect(.degrees(pebble.rotation))
                            .scaleEffect(draggingId == pebble.id ? 1.08 : 1.0)
                            .offset(pebble.offset)
                            .shadow(
                                color: .black.opacity(draggingId == pebble.id ? 0.35 : 0.2),
                                radius: draggingId == pebble.id ? 12 : 4,
                                y: draggingId == pebble.id ? 8 : 2
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        draggingId = pebble.id
                                        if startOffsets[pebble.id] == nil {
                                            startOffsets[pebble.id] = pebble.offset
                                        }
                                        if let start = startOffsets[pebble.id] {
                                            pebble.offset = CGSize(
                                                width: start.width + value.translation.width,
                                                height: start.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                            pebble.offset = CGSize(
                                                width: pebble.offset.width + value.translation.width * 0.0,
                                                height: pebble.offset.height + value.translation.height * 0.0
                                            )
                                            pebble.rotation += Double.random(in: -8...8)
                                        }
                                        draggingId = nil
                                        startOffsets[pebble.id] = nil
                                    }
                            )
                            .animation(.easeOut(duration: 0.2), value: draggingId == pebble.id)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("No goal. No timer. Just this.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.subtleGray.opacity(0.4))
                    .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .onAppear { generatePebbles() }
    }

    private func generatePebbles() {
        pebbles = (0..<6).map { i in
            Pebble(
                offset: CGSize(
                    width: CGFloat.random(in: -100...100),
                    height: CGFloat.random(in: -120...120)
                ),
                rotation: Double.random(in: -25...25),
                color: pebbleColors[i % pebbleColors.count],
                width: CGFloat.random(in: 80...140),
                height: CGFloat.random(in: 44...72)
            )
        }
    }
}

