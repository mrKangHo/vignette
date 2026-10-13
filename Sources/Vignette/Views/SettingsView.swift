import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var movieMode: MovieModeController

    init(appState: AppState) {
        self.appState = appState
        self.movieMode = appState.movieMode
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    ForEach(appState.displayManager.displays) { display in
                        DisplayRowView(appState: appState, display: display)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("디스플레이별 밝기", systemImage: "display.2")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("재생 중인 모니터를 제외한 나머지 모니터를 그라데이션으로 어둡게 만듭니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Slider(value: $movieMode.dimIntensity, in: 0...1) {
                        Text("어둡게 하는 정도")
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("영화 감상 모드", systemImage: "film")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 360)
    }
}
