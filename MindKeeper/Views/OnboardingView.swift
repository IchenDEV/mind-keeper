import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0

    private let steps: [(icon: String, title: String, desc: String)] = [
        ("bell.badge.fill", "通知监听",
         "Mind Keeper 会读取系统通知数据库来获取通知内容，需要授予「完全磁盘访问」权限。"),
        ("brain.head.profile.fill", "智能分类",
         "通过本地 AI 模型自动分析通知的优先级，无需上传任何数据到云端。需要安装 Ollama。"),
        ("hand.draw.fill", "手势操作",
         "上滑完成、左滑延迟、右滑丢弃。简单直觉的手势让你快速处理每一条事务。")
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            stepContent
            Spacer()
            pageIndicator
            actionArea
        }
        .padding(20)
    }

    private var stepContent: some View {
        let step = steps[currentStep]
        return VStack(spacing: 16) {
            Image(systemName: step.icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating)

            Text(step.title)
                .font(.title3.weight(.semibold))

            Text(step.desc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 16)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { i in
                Circle()
                    .fill(i == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            if currentStep < steps.count - 1 {
                primaryButton("下一步") {
                    withAnimation(.spring(.smooth(duration: 0.35))) { currentStep += 1 }
                }
            } else {
                primaryButton("前往系统设置") {
                    openFullDiskAccessSettings()
                }

                Button {
                    withAnimation(.spring(.smooth(duration: 0.35))) {
                        appState.activePanel = .cardStack
                    }
                } label: {
                    Text("稍后设置")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.tint, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
