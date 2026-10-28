import AppKit
import Testing
import Defaults
@testable import Maccy

extension SharedStateTests {
  // swiftlint:disable type_body_length
  @MainActor
  final class ClipboardTests {
    let clipboard = Clipboard.shared
    let pasteboard = Clipboard.shared.pasteboard
    let image: NSImage
    let coloredString = NSAttributedString(string: "foo",
                                           attributes: [.foregroundColor: NSColor.red])

    let dynamicType = NSPasteboard.PasteboardType(rawValue: "dyn.ah62d4qmxhk4d425try1g44pdsm11g55gsu1e82xnqzv")
    let customType = NSPasteboard.PasteboardType(rawValue: "org.maccy.ConfidentialType")
    let fileURLType = NSPasteboard.PasteboardType.fileURL
    let htmlType = NSPasteboard.PasteboardType.html
    let rtfType = NSPasteboard.PasteboardType.rtf
    let stringType = NSPasteboard.PasteboardType.string
    let tiffType = NSPasteboard.PasteboardType.tiff
    let transientType = NSPasteboard.PasteboardType.transient
    let unknownType = NSPasteboard.PasteboardType(rawValue: "com.apple.AnnotationKit.AnnotationItem")

    let savedEnabledTypes = Defaults[.enabledPasteboardTypes]
    let savedIgnoreEvents = Defaults[.ignoreEvents]
    let savedIgnoreAllAppsExceptListed = Defaults[.ignoreAllAppsExceptListed]
    let savedIgnoredApps = Defaults[.ignoredApps]
    let savedIgnoredPasteboardTypes = Defaults[.ignoredPasteboardTypes]

    init() throws {
      image = try #require(NSImage(named: "NSInfo"))
      Defaults[.ignoreAllAppsExceptListed] = false
      Defaults[.ignoreEvents] = false
      clipboard.clearHooks()
    }

    deinit {
      Defaults[.enabledPasteboardTypes] = savedEnabledTypes
      Defaults[.ignoreEvents] = savedIgnoreEvents
      Defaults[.ignoreOnlyNextEvent] = false
      Defaults[.ignoreAllAppsExceptListed] = savedIgnoreAllAppsExceptListed
      Defaults[.ignoredApps] = savedIgnoredApps
      Defaults[.ignoredPasteboardTypes] = savedIgnoredPasteboardTypes
    }

    @Test("Changes listener and add hooks")
    func changesListenerAndAddHooks() async throws {
      let copies = try await waitForCopies(after: {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("bar", forType: .string)
      })
      #expect(copies.count == 1)
    }

    @Test("Ignore string with only spaces")
    func ignoreStringWithOnlySpaces() async throws {
      let copies = try await waitForCopies(expectingCopy: false, after: {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(" ", forType: .string)
      })
      #expect(copies.isEmpty)
    }

    @Test("Ignore string with only newlines")
    func ignoreStringWithOnlyNewlines() async throws {
      let copies = try await waitForCopies(expectingCopy: false, after: {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("\n", forType: .string)
      })
      #expect(copies.isEmpty)
    }

    @Test("Does not ignore RTF")
    func doesNotIgnoreRTF() async throws {
      let copies = try await waitForCopies(after: {
        let rtf = NSAttributedString(string: "foo").rtf(
          from: NSRange(0...2),
          documentAttributes: [:]
        )
        pasteboard.declareTypes([.rtf], owner: nil)
        pasteboard.setData(rtf, forType: .rtf)
      })
      #expect(copies.count == 1)
    }

    @Test("Does not ignore HTML")
    func doesNotIgnoreHTML() async throws {
      let copies = try await waitForCopies(after: {
        pasteboard.declareTypes([.html], owner: nil)
        pasteboard.setString("foo", forType: .html)
      })
      #expect(copies.count == 1)
    }

    @Test("Ignore events is enabled")
    func ignoreEventsIsEnabled() async throws {
      Defaults[.ignoreEvents] = true

      let copies = try await waitForCopies(expectingCopy: false, after: {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("foo", forType: .string)
      })
      #expect(copies.isEmpty)
    }

    @Test("Ignore only next event is enabled")
    func ignoreOnlyNextEventIsEnabled() async throws {
      Defaults[.ignoreEvents] = true
      Defaults[.ignoreOnlyNextEvent] = true

      let copies = try await waitForCopies(expectingCopy: false, after: {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("foo", forType: .string)
      })
      #expect(copies.isEmpty)

      #expect(!Defaults[.ignoreEvents])
      #expect(!Defaults[.ignoreOnlyNextEvent])
    }

    @Test("Ignore application")
    func ignoreApplication() async throws {
      Defaults[.ignoredApps] = [try frontmostAppBundleIdentifier()]

      let copies = try await waitForCopies(expectingCopy: false, after: {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("bar", forType: .string)
      })
      #expect(copies.isEmpty)
    }

    @Test("Ignore all applications except")
    func ignoreAllApplicationsExcept() async throws {
      Defaults[.ignoreAllAppsExceptListed] = true
      Defaults[.ignoredApps] = [try frontmostAppBundleIdentifier()]

      let copies = try await waitForCopies(after: {
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("bar", forType: .string)
      })
      #expect(copies.count == 1)
    }

    @Test("Ignore transient types")
    func ignoreTransientTypes() async throws {
      let copies = try await waitForCopies(expectingCopy: false, after: {
        pasteboard.declareTypes([.string, transientType], owner: nil)
        pasteboard.setString("bar", forType: .string)
      })
      #expect(copies.isEmpty)
    }

    @Test("Ignore custom types")
    func ignoreCustomTypes() async throws {
      Defaults[.ignoredPasteboardTypes] = [customType.rawValue]

      let copies = try await waitForCopies(expectingCopy: false, after: {
        pasteboard.declareTypes([.string, customType], owner: nil)
        pasteboard.setString("bar", forType: .string)
      })
      #expect(copies.isEmpty)
    }

    @Test("Ignore copies with unknown types")
    func ignoreCopiesWithUnknownTypes() async throws {
      let copies = try await waitForCopies(expectingCopy: false, after: {
        pasteboard.declareTypes([unknownType], owner: nil)
        pasteboard.setString(" ", forType: unknownType)
      })
      #expect(copies.isEmpty)
    }

    @Test("Copy")
    func copy() {
      let imageData = image.tiffRepresentation!
      let contents = [
        HistoryItemContent(type: stringType.rawValue, value: "foo".data(using: .utf8)!),
        HistoryItemContent(type: tiffType.rawValue, value: imageData),
        HistoryItemContent(type: fileURLType.rawValue, value: "file://foo.bar".data(using: .utf8)!)
      ]
      let item = HistoryItem()
      Storage.shared.context.insert(item)
      item.contents = contents
      item.application = "com.foo.bar"
      clipboard.copy(item)
      #expect(pasteboard.string(forType: .string) == "foo")
      #expect(pasteboard.data(forType: .tiff) == imageData)
      #expect(pasteboard.string(forType: .fileURL) == "file://foo.bar")
      #expect(pasteboard.string(forType: .fromMaccy) == "")
      #expect(pasteboard.string(forType: .source) == "com.foo.bar")
    }

    @Test("New copy has trailing newlines removed")
    func newCopyHasTrailingNewlinesRemoved() {
      Defaults[.removeTrailingNewlines] = true
      defer { Defaults.reset(.removeTrailingNewlines) }
      var captured: HistoryItem?
      clipboard.onNewCopy({ captured = $0 })
      pasteboard.declareTypes([.string, .html], owner: nil)
      pasteboard.setString("foo\n\n", forType: .string)
      pasteboard.setString("<b>foo</b><br><br>", forType: .html)
      clipboard.checkForChangesInPasteboard()
      #expect(pasteboard.string(forType: .string) == "foo")
      #expect(pasteboard.data(forType: .html) == nil)
      let rtf = pasteboard.data(forType: .rtf).flatMap { NSAttributedString(rtf: $0, documentAttributes: nil) }
      #expect(rtf?.string == "foo")
      #expect(captured?.contents.first { $0.type == stringType.rawValue }?.value == "foo".data(using: .utf8))
      // The rewrite itself isn't recorded as another copy.
      captured = nil
      clipboard.checkForChangesInPasteboard()
      #expect(captured == nil)
    }

    @Test("New copy from a browser has trailing newlines removed")
    func newCopyFromABrowserHasTrailingNewlinesRemoved() {
      Defaults[.removeTrailingNewlines] = true
      defer { Defaults.reset(.removeTrailingNewlines) }
      clipboard.onNewCopy({ _ in })
      pasteboard.declareTypes([.string, .html, .chromiumSourceUrl, .chromiumSourceToken], owner: nil)
      pasteboard.setString("foo\n", forType: .string)
      pasteboard.setString("<div>foo</div>", forType: .html)
      pasteboard.setString("https://example.com", forType: .chromiumSourceUrl)
      pasteboard.setString("token", forType: .chromiumSourceToken)
      clipboard.checkForChangesInPasteboard()
      #expect(pasteboard.string(forType: .string) == "foo")
      #expect(pasteboard.string(forType: .chromiumSourceUrl) == "https://example.com")
      #expect(pasteboard.string(forType: .chromiumSourceToken) == "token")
    }

    @Test("New copy with other types is left alone")
    func newCopyWithOtherTypesIsLeftAlone() {
      Defaults[.removeTrailingNewlines] = true
      defer { Defaults.reset(.removeTrailingNewlines) }
      clipboard.onNewCopy({ _ in })
      pasteboard.declareTypes([.string, customType], owner: nil)
      pasteboard.setString("foo\n", forType: .string)
      pasteboard.setString("cells", forType: customType)
      clipboard.checkForChangesInPasteboard()
      #expect(pasteboard.string(forType: .string) == "foo\n")
      #expect(pasteboard.string(forType: customType) == "cells")
    }

    @Test("New copy with an unstored text type is left alone")
    func newCopyWithAnUnstoredTextTypeIsLeftAlone() {
      Defaults[.removeTrailingNewlines] = true
      defer { Defaults.reset(.removeTrailingNewlines) }
      Defaults[.enabledPasteboardTypes] = savedEnabledTypes.subtracting([.html])
      clipboard.onNewCopy({ _ in })
      pasteboard.declareTypes([.string, .html], owner: nil)
      pasteboard.setString("foo\n", forType: .string)
      pasteboard.setString("<b>foo</b><br>", forType: .html)
      clipboard.checkForChangesInPasteboard()
      #expect(pasteboard.string(forType: .string) == "foo\n")
      #expect(pasteboard.string(forType: .html) == "<b>foo</b><br>")
    }

    @Test("New copy keeps trailing newlines when disabled")
    func newCopyKeepsTrailingNewlinesWhenDisabled() {
      Defaults[.removeTrailingNewlines] = false
      defer { Defaults.reset(.removeTrailingNewlines) }
      clipboard.onNewCopy({ _ in })
      pasteboard.declareTypes([.string], owner: nil)
      pasteboard.setString("foo\n", forType: .string)
      clipboard.checkForChangesInPasteboard()
      #expect(pasteboard.string(forType: .string) == "foo\n")
    }

    @Test("Copy removes trailing newlines")
    func copyRemovesTrailingNewlines() throws {
      Defaults[.removeTrailingNewlines] = true
      defer { Defaults.reset(.removeTrailingNewlines) }
      let richString = NSAttributedString(string: "foo\nbar\n\n", attributes: [.foregroundColor: NSColor.red])
      let contents = [
        HistoryItemContent(type: stringType.rawValue, value: "foo\nbar\r\n\n".data(using: .utf8)!),
        HistoryItemContent(type: rtfType.rawValue,
                           value: richString.rtf(from: NSRange(location: 0, length: richString.length),
                                                 documentAttributes: [:])),
        HistoryItemContent(type: htmlType.rawValue, value: "<p>foo</p><p>bar</p>".data(using: .utf8)!)
      ]
      let item = HistoryItem()
      Storage.shared.context.insert(item)
      item.contents = contents
      clipboard.copy(item)
      #expect(pasteboard.string(forType: .string) == "foo\nbar")
      let rtf = try #require(pasteboard.data(forType: .rtf).flatMap { NSAttributedString(rtf: $0, documentAttributes: nil) })
      #expect(rtf.string == "foo\nbar")
      let color = rtf.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
      #expect(color?.usingColorSpace(.sRGB)?.redComponent == 1)
      #expect(pasteboard.data(forType: .html) == nil)
      // The stored history item keeps its original value.
      #expect(item.contents.first { $0.type == stringType.rawValue }?.value == "foo\nbar\r\n\n".data(using: .utf8)!)
    }

    @Test("Copy removes trailing newlines from HTML-only rich text")
    func copyRemovesTrailingNewlinesFromHTMLOnlyRichText() throws {
      Defaults[.removeTrailingNewlines] = true
      defer { Defaults.reset(.removeTrailingNewlines) }
      let item = HistoryItem()
      Storage.shared.context.insert(item)
      item.contents = [
        HistoryItemContent(type: stringType.rawValue, value: "foo\n".data(using: .utf8)!),
        HistoryItemContent(type: htmlType.rawValue, value: "<b>foo</b><br>".data(using: .utf8)!)
      ]
      clipboard.copy(item)
      #expect(pasteboard.string(forType: .string) == "foo")
      #expect(pasteboard.data(forType: .html) == nil)
      let rtf = try #require(pasteboard.data(forType: .rtf).flatMap { NSAttributedString(rtf: $0, documentAttributes: nil) })
      #expect(rtf.string == "foo")
    }

    @Test("Copy keeps trailing newlines when disabled")
    func copyKeepsTrailingNewlinesWhenDisabled() {
      Defaults[.removeTrailingNewlines] = false
      defer { Defaults.reset(.removeTrailingNewlines) }
      let item = HistoryItem()
      Storage.shared.context.insert(item)
      item.contents = [
        HistoryItemContent(type: stringType.rawValue, value: "foo\n".data(using: .utf8)!),
        HistoryItemContent(type: htmlType.rawValue, value: "<p>foo</p>".data(using: .utf8)!)
      ]
      clipboard.copy(item)
      #expect(pasteboard.string(forType: .string) == "foo\n")
      #expect(pasteboard.data(forType: .html) != nil)
    }

    @Test("Copy without trailing newlines leaves other text alone")
    func copyWithoutTrailingNewlinesLeavesOtherTextAlone() {
      Defaults[.removeTrailingNewlines] = true
      defer { Defaults.reset(.removeTrailingNewlines) }
      let item = HistoryItem()
      Storage.shared.context.insert(item)
      item.contents = [
        HistoryItemContent(type: stringType.rawValue, value: "\nfoo  ".data(using: .utf8)!),
        HistoryItemContent(type: htmlType.rawValue, value: "<p>foo</p>".data(using: .utf8)!)
      ]
      clipboard.copy(item)
      #expect(pasteboard.string(forType: .string) == "\nfoo  ")
      #expect(pasteboard.data(forType: .html) != nil)
    }

    @Test("Copy string")
    func copyString() {
      clipboard.copyInMaccy("foo")
      #expect(pasteboard.string(forType: .string) == "foo")
      #expect(pasteboard.string(forType: .source) == NSPasteboard.PasteboardType.fromMaccy.rawValue)
    }

    @Test("Copy without formatting")
    func copyWithoutFormatting() {
      let contents = [
        HistoryItemContent(type: stringType.rawValue, value: "foo".data(using: .utf8)!),
        HistoryItemContent(type: fileURLType.rawValue, value: "file://foo.bar".data(using: .utf8)!),
        HistoryItemContent(type: rtfType.rawValue,
                           value: coloredString.rtf(from: NSRange(location: 0, length: coloredString.length),
                                                    documentAttributes: [:]))
      ]
      let item = HistoryItem()
      Storage.shared.context.insert(item)
      item.contents = contents
      item.application = "com.foo.bar"
      clipboard.copy(item, removeFormatting: true)
      #expect(pasteboard.string(forType: .string) == "foo")
      #expect(pasteboard.string(forType: .fromMaccy) == "")
      #expect(pasteboard.string(forType: .source) == "com.foo.bar")
      #expect(pasteboard.string(forType: .fileURL) == "file://foo.bar")
      #expect(pasteboard.data(forType: .rtf) == nil)
    }

    @Test("Handles items without data")
    func handlesItemsWithoutData() async throws {
      pasteboard.clearContents()

      let copies = try await waitForCopies(after: {
        pasteboard.declareTypes([.fileURL, .string], owner: nil)
        // fileURL is left without data
        pasteboard.setString("bar", forType: .string)
      })
      #expect(copies.count == 1)
    }

    @Test("Merges multiple items")
    func mergesMultipleItems() async throws {
      let item1 = NSPasteboardItem()
      item1.setString("foo", forType: .string)
      let item2 = NSPasteboardItem()
      item2.setData(image.tiffRepresentation!, forType: .tiff)

      let copies = try await waitForCopies(after: {
        pasteboard.clearContents()
        pasteboard.writeObjects([item1, item2])
      })
      let copied = try #require(copies.first)
      #expect(copies.count == 1)
      #expect(
        Set(copied.contents.map({ $0.type })) ==
        Set([tiffType.rawValue, stringType.rawValue])
      )
    }

    @Test("Drops TIFF when PNG is present")
    func dropsTIFFWhenPNGPresent() async throws {
      let bitmap = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
      let item = NSPasteboardItem()
      item.setData(try #require(bitmap.representation(using: .png, properties: [:])), forType: .png)
      item.setData(try #require(bitmap.tiffRepresentation), forType: .tiff)

      let copies = try await waitForCopies(after: {
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
      })
      let copied = try #require(copies.first)
      #expect(copied.contents.map({ $0.type }) == [NSPasteboard.PasteboardType.png.rawValue])
    }

    @Test("Copy offers TIFF from PNG")
    func copyOffersTIFFFromPNG() throws {
      let png = try #require(
        image.tiffRepresentation
          .flatMap(NSBitmapImageRep.init(data:))?
          .representation(using: .png, properties: [:])
      )
      let item = HistoryItem()
      Storage.shared.context.insert(item)
      item.contents = [HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: png)]
      clipboard.copy(item)
      #expect(pasteboard.data(forType: .png) == png)
      let tiff = pasteboard.data(forType: .tiff)
      #expect(tiff != nil)
      #expect(tiff.flatMap(NSBitmapImageRep.init(data:))?.pixelsWide == NSBitmapImageRep(data: png)?.pixelsWide)
    }

    @Test("Removes disabled types")
    func removesDisabledTypes() async throws {
      Defaults[.enabledPasteboardTypes] = [.fileURL]

      let item = NSPasteboardItem()
      item.setString("foo", forType: .string)
      item.setData(image.tiffRepresentation!, forType: .tiff)
      item.setData("file://foo.bar".data(using: .utf8)!, forType: .fileURL)

      let copies = try await waitForCopies(after: {
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
      })
      let copied = try #require(copies.first)
      #expect(copies.count == 1)
      #expect(copied.contents.map({ $0.type }) == [fileURLType.rawValue])
    }

    @Test("Removes dynamic types")
    func removesDynamicTypes() async throws {
      let item = NSPasteboardItem()
      item.setString("foo", forType: .string)
      item.setData("".data(using: .utf8)!, forType: dynamicType)

      let copies = try await waitForCopies(after: {
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
      })
      let copied = try #require(copies.first)
      #expect(copies.count == 1)
      #expect(copied.contents.map({ $0.type }) == [stringType.rawValue])
    }

    @Test("Does not store Safari web archive")
    func doesNotStoreSafariWebArchive() async throws {
      let webArchive = NSPasteboard.PasteboardType.safariWebArchve

      let item = NSPasteboardItem()
      item.setString("hello from safari", forType: .string)
      item.setData(Data(repeating: 0x61, count: 1024 * 1024), forType: webArchive)

      let copies = try await waitForCopies(after: {
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
      })
      let copied = try #require(copies.first)
      #expect(copies.count == 1)
      #expect(Set(copied.contents.map(\.type)) == [stringType.rawValue])
    }

    private func waitForCopies(expectingCopy: Bool = true, after trigger: () -> Void) async throws -> [HistoryItem] {
      var copies: [HistoryItem] = []
      clipboard.onNewCopy { copies.append($0) }
      clipboard.start()
      trigger()
      let deadline = ContinuousClock.now + .seconds(2)
      while (!expectingCopy || copies.isEmpty) && ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(50))
      }
      return copies
    }

    @Test("Advanced settings' pause snippets name this build's defaults domain")
    func pauseSnippetUsesBundleIdentifier() {
      let raw = "defaults write org.p0deje.Maccy ignoreEvents true\n# copy data\ndefaults write org.p0deje.Maccy ignoreEvents false"
      #expect(AdvancedSettingsPane.snippet(raw, bundleID: "com.lockyc.maccy")
        == "defaults write com.lockyc.maccy ignoreEvents true\n# copy data\ndefaults write com.lockyc.maccy ignoreEvents false")
    }

    private func frontmostAppBundleIdentifier() throws -> String {
      guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
        try Test.cancel("No frontmost application to attribute a copy to")
      }

      return bundleIdentifier
    }
  }
  // swiftlint:enable type_body_length
}
