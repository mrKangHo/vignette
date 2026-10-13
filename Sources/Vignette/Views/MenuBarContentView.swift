import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var movieMode: MovieModeController

    init(appState: AppState) {
        self.appState = appState
        self.movieMode = appState.movieMode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("디스플레이")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.2)

            VStack(spacing: 10) {
                ForEach(appState.displayManager.displays) { display in
                    DisplayRowView(appState: appState, display: display)
                }
            }

            movieModeCard

            Divider()

            HStack(spacing: 16) {
                Button {
                    appState.settingsWindowController.show(appState: appState)
                } label: {
                    Label("설정", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("종료", systemImage: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .padding(16)
        .frame(width: 280)
        .background(.regularMaterial)
        .animation(.easeInOut(duration: 0.2), value: movieMode.isActive)
    }

    private var movieModeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("영화 감상 모드", systemImage: "film")
                Spacer()
                Toggle("영화 감상 모드", isOn: movieModeBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if movieMode.isActive {
                Picker("재생 중인 모니터", selection: activeDisplayBinding) {
                    ForEach(appState.displayManager.displays) { display in
                        Text(display.name).tag(Optional(display.id))
                    }
                }
                .pickerStyle(.menu)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary))
    }

    private var movieModeBinding: Binding<Bool> {
        Binding(
            get: { movieMode.isActive },
            set: { isOn in
                guard let first = appState.displayManager.displays.first else { return }
                let active = appState.displayManager.displays.first { $0.id == movieMode.activeDisplayID } ?? first
                if isOn {
                    movieMode.start(activeDisplayID: active.id)
                } else {
                    movieMode.stop()
                }
            }
        )
    }

    private var activeDisplayBinding: Binding<CGDirectDisplayID?> {
        Binding(
            get: { movieMode.activeDisplayID },
            set: { newValue in
                guard let newValue else { return }
                movieMode.selectActiveDisplay(newValue)
            }
        )
    }
}
