import SwiftUI
import Defaults

struct AdvancedSettingsPane: View {
  var body: some View {
    VStack(alignment: .leading) {
      Defaults.Toggle(key: .ignoreEvents) {
        Text("TurnOff", tableName: "AdvancedSettings")
      }
      Text("TurnOffDescription", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
      Text(verbatim: Self.localizedSnippet("TurnOffShellScript"))
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .font(.system(size: 11, design: .monospaced))
        .controlSize(.small)
        .padding(.vertical, 2)
      Text("TurnOffViaMenuIconDescription", tableName: "AdvancedSettings")
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .controlSize(.small)
      Text(verbatim: Self.localizedSnippet("TurnOffNextShellScript"))
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.gray)
        .font(.system(size: 11, design: .monospaced))
        .controlSize(.small)
        .padding(.vertical, 2)

      Divider()

      Defaults.Toggle(key: .clearOnQuit) {
        Text("ClearHistoryOnQuit", tableName: "AdvancedSettings")
      }.help(Text("ClearHistoryOnQuitTooltip", tableName: "AdvancedSettings"))

      Defaults.Toggle(key: .clearSystemClipboard) {
        Text("ClearSystemClipboard", tableName: "AdvancedSettings")
      }.help(Text("ClearSystemClipboardTooltip", tableName: "AdvancedSettings"))
    }
    .frame(minWidth: 350, maxWidth: 450)
    .padding()
  }

  // The translations spell upstream's defaults domain; a build under another bundle ID
  // (the lockyc fork) shows its own, without touching every .lproj.
  static func snippet(_ raw: String, bundleID: String) -> String {
    raw.replacingOccurrences(of: "org.p0deje.Maccy", with: bundleID)
  }

  private static func localizedSnippet(_ key: String.LocalizationValue) -> String {
    snippet(String(localized: key, table: "AdvancedSettings"),
            bundleID: Bundle.main.bundleIdentifier ?? "org.p0deje.Maccy")
  }
}

#Preview {
  AdvancedSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
