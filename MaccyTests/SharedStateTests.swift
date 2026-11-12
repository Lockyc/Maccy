import Defaults
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

    @Test("Row settings follow their defaults")
    func followDefaults() async throws {
      let appState = AppState.shared
      Defaults[.showApplicationIcons] = !savedShowIcons
      Defaults[.showHexColorSwatch] = !savedShowSwatch
      try await Task.sleep(for: .milliseconds(100))
      #expect(appState.showApplicationIcons == !savedShowIcons)
      #expect(appState.showHexColorSwatch == !savedShowSwatch)
    }
  }
}
