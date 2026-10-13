import SwiftUI

struct DisplayRowView: View {
    @ObservedObject var appState: AppState
    let display: Display

    @State private var settings: DisplaySettings

    init(appState: AppState, display: Display) {
        self.appState = appState
        self.display = display
        _settings = State(initialValue: appState.settings(for: display))
    }

    private var usesHardwareBrightness: Bool {
        appState.supportsHardwareBrightness(for: display)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(display.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if display.isBuiltIn {
                    Text("내장")
                        .font(.caption2.weight(.medium))
                        .tracking(0.2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.quaternary))
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "sun.min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { settings.brightness },
                        set: { newValue in
                            settings.brightness = newValue
                            appState.updateSettings(settings, for: display)
                            if usesHardwareBrightness {
                                appState.applyHardwareBrightnessNow(newValue, for: display)
                            }
                        }
                    ),
                    in: 0...1
                )

                Image(systemName: usesHardwareBrightness ? "sun.max.fill" : "sun.max")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help(usesHardwareBrightness ? "실제 밝기로 조절됩니다" : "소프트웨어로 어둡게 조절됩니다")
            }
        }
        .onChange(of: display) { newDisplay in
            settings = appState.settings(for: newDisplay)
        }
    }
}
