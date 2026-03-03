import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppCoordinator.self) private var coordinator
    @AppStorage("ollamaModel") private var ollamaModel = "llama3.2"
    @AppStorage("cloudAPIKey") private var cloudAPIKey = ""
    @AppStorage("cloudEndpoint") private var cloudEndpoint = ""
    @AppStorage("pollInterval") private var pollInterval = 4.0
    @AppStorage("urgentSoundEnabled") private var urgentSoundEnabled = true
    @AppStorage("notifAgingHours") private var notifAgingHours = 24.0
    @AppStorage("notifExpiredHours") private var notifExpiredHours = 72.0
    @AppStorage("manualAgingDays") private var manualAgingDays = 7.0
    @AppStorage("manualExpiredDays") private var manualExpiredDays = 14.0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            settingsContent
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(.smooth(duration: 0.3))) {
                    appState.activePanel = .cardStack
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text("设置")
                .font(.system(size: 13, weight: .medium))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var settingsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                settingsSection("AI 模型") {
                    SettingsRow("Ollama 模型") {
                        TextField("模型名称", text: $ollamaModel)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                    SettingsRow("状态") {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(appState.isOllamaAvailable ? .green : .red)
                                .frame(width: 6, height: 6)
                            Text(appState.isOllamaAvailable ? "已连接" : "未连接")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("刷新") {
                                coordinator.reloadLLMConfig()
                            }
                            .font(.caption2)
                        }
                    }
                }

                settingsSection("云端回退") {
                    SettingsRow("API Key") {
                        SecureField("sk-...", text: $cloudAPIKey)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                    SettingsRow("Endpoint") {
                        TextField("留空用 OpenAI 默认", text: $cloudEndpoint)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                    }
                }

                settingsSection("紧急任务") {
                    SettingsRow("声音提醒") {
                        Toggle("", isOn: $urgentSoundEnabled)
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                            .frame(width: 40)
                    }
                    SettingsRow("说明") {
                        Text("紧急消息到达时播放提示音")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                settingsSection("通知轮询") {
                    SettingsRow("检查间隔") {
                        Picker("", selection: $pollInterval) {
                            Text("2s").tag(2.0)
                            Text("4s").tag(4.0)
                            Text("8s").tag(8.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }

                settingsSection("过期策略") {
                    compactRow("通知老化", value: $notifAgingHours, range: 6...168, step: 6, unit: "h")
                    compactRow("通知过期", value: $notifExpiredHours, range: 24...720, step: 24, unit: "h")
                    compactRow("手动老化", value: $manualAgingDays, range: 1...30, step: 1, unit: "天")
                    compactRow("手动过期", value: $manualExpiredDays, range: 3...60, step: 1, unit: "天")
                }

                settingsSection("调试") {
                    SettingsRow("磁盘权限") {
                        Text(appState.hasFullDiskAccess ? "✓ 已授权" : "✗ 未授权")
                            .font(.caption)
                            .foregroundStyle(appState.hasFullDiskAccess ? .green : .orange)
                    }
                    HStack(spacing: 8) {
                        Button("加载演示数据") { coordinator.loadDemoData() }
                            .font(.caption)
                        Spacer()
                        Button("重置引导") {
                            UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
                            UserDefaults.standard.removeObject(forKey: "demoSeeded")
                            appState.activePanel = .onboarding
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                settingsSection("关于") {
                    SettingsRow("版本") {
                        Text("1.0.0")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .clipShape(Rectangle())
    }

    // MARK: - Compact Number Row

    private func compactRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.callout)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button {
                    let v = value.wrappedValue - step
                    if v >= range.lowerBound { value.wrappedValue = v }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("\(Int(value.wrappedValue))\(unit)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(width: 42)
                    .multilineTextAlignment(.center)

                Button {
                    let v = value.wrappedValue + step
                    if v <= range.upperBound { value.wrappedValue = v }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            VStack(spacing: 1) {
                content()
            }
            .padding(10)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let label: String
    let trailing: Trailing

    init(_ label: String, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 3)
    }
}
