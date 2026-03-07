import SwiftUI

struct RobotFaceView: View {
    let state: RobotState

    private var eyeColor: Color {
        switch state {
        case .idle:
            return .cyan
        case .listening:
            return .green
        case .thinking:
            return .orange
        case .speaking:
            return .blue
        }
    }

    private var mouthHeight: CGFloat {
        switch state {
        case .idle:
            return 8
        case .listening:
            return 4
        case .thinking:
            return 10
        case .speaking:
            return 16
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.9), Color.gray.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 18) {
                HStack(spacing: 24) {
                    Circle()
                        .fill(eyeColor)
                        .frame(width: 16, height: 16)
                    Circle()
                        .fill(eyeColor)
                        .frame(width: 16, height: 16)
                }

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 68, height: mouthHeight)
            }
        }
        .frame(height: 130)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: state)
    }
}
