import Defaults
import Observation
import Testing
@testable import Maccy

@Suite(.serialized)
enum SharedStateTests {}

extension SharedStateTests {
  @MainActor
  final class RowSettingsTests {
    let savedShowIcons = Defaults[.showApplicationIcons]
    let savedShowSwatch = Defaults[.showHexColorSwatch]

    deinit {
      Defaults[.showApplicationIcons] = savedShowIcons
      Defaults[.showHexColorSwatch] = savedShowSwatch
    }

    @Test("Row settings follow their defaults", .timeLimit(.minutes(1)))
    func followDefaults() async throws {
      let appState = AppState.shared
      await change(of: { appState.showApplicationIcons }) {
        Defaults[.showApplicationIcons] = !savedShowIcons
      }
      await change(of: { appState.showHexColorSwatch }) {
        Defaults[.showHexColorSwatch] = !savedShowSwatch
      }
      #expect(appState.showApplicationIcons == !savedShowIcons)
      #expect(appState.showHexColorSwatch == !savedShowSwatch)
    }

    // Returns once `property` changes after `trigger` runs, however long AppState takes.
    private func change<T>(of property: @escaping () -> T, after trigger: () -> Void) async {
      await withCheckedContinuation { continuation in
        withObservationTracking { _ = property() } onChange: { continuation.resume() }
        trigger()
      }
    }
  }
}
