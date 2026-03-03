import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 42, weight: .ultraLight))
                    .foregroundStyle(.secondary.opacity(0.35))

                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .offset(x: 24, y: -18)
            }

            VStack(spacing: 4) {
                Text("一切就绪")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("点击右上角 + 手动添加任务")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
