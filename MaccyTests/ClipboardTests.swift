import XCTest
import Defaults
@testable import Maccy

// swiftlint:disable type_body_length
@MainActor
class ClipboardTests: XCTestCase {
  let clipboard = Clipboard.shared
  let pasteboard = Clipboard.shared.pasteboard
  let image = NSImage(named: "NSInfo")!
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

  override func setUp() {
    super.setUp()
    Defaults[.ignoreAllAppsExceptListed] = false
    Defaults[.ignoreEvents] = false
  }

  override func tearDown() {
    super.tearDown()
    Defaults[.enabledPasteboardTypes] = savedEnabledTypes
    Defaults[.ignoreEvents] = savedIgnoreEvents
    Defaults[.ignoreOnlyNextEvent] = false
    Defaults[.ignoreAllAppsExceptListed] = savedIgnoreAllAppsExceptListed
    Defaults[.ignoredApps] = savedIgnoredApps
    Defaults[.ignoredPasteboardTypes] = savedIgnoredPasteboardTypes
    MainActor.assumeIsolated {
      Clipboard.shared.clearHooks()
    }
  }

  func testChangesListenerAndAddHooks() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreStringWithOnlySpaces() {
    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(" ", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreStringWithOnlyNewlines() {
    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("\n", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testDoesNotIgnoreRTF() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    let rtf = NSAttributedString(string: "foo").rtf(
      from: NSRange(0...2),
      documentAttributes: [:]
    )
    pasteboard.declareTypes([.rtf], owner: nil)
    pasteboard.setData(rtf, forType: .rtf)
    waitForExpectations(timeout: 2)
  }

  func testDoesNotIgnoreHTML() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.html], owner: nil)
    pasteboard.setString("foo", forType: .html)
    waitForExpectations(timeout: 2)
  }

  func testNewCopyHasTrailingNewlinesRemoved() {
    Defaults[.removeTrailingNewlines] = true
    defer { Defaults.reset(.removeTrailingNewlines) }
    var captured: HistoryItem?
    clipboard.onNewCopy({ captured = $0 })
    pasteboard.declareTypes([.string, .html], owner: nil)
    pasteboard.setString("foo\n\n", forType: .string)
    pasteboard.setString("<b>foo</b><br><br>", forType: .html)
    clipboard.checkForChangesInPasteboard()
    XCTAssertEqual(pasteboard.string(forType: .string), "foo")
    XCTAssertNil(pasteboard.data(forType: .html))
    let rtf = pasteboard.data(forType: .rtf).flatMap { NSAttributedString(rtf: $0, documentAttributes: nil) }
    XCTAssertEqual(rtf?.string, "foo")
    XCTAssertEqual(captured?.contents.first { $0.type == stringType.rawValue }?.value, "foo".data(using: .utf8))
    // The rewrite itself isn't recorded as another copy.
    captured = nil
    clipboard.checkForChangesInPasteboard()
    XCTAssertNil(captured)
  }

  func testNewCopyWithOtherTypesIsLeftAlone() {
    Defaults[.removeTrailingNewlines] = true
    defer { Defaults.reset(.removeTrailingNewlines) }
    clipboard.onNewCopy({ _ in })
    pasteboard.declareTypes([.string, customType], owner: nil)
    pasteboard.setString("foo\n", forType: .string)
    pasteboard.setString("cells", forType: customType)
    clipboard.checkForChangesInPasteboard()
    XCTAssertEqual(pasteboard.string(forType: .string), "foo\n")
    XCTAssertEqual(pasteboard.string(forType: customType), "cells")
  }

  func testNewCopyWithAnUnstoredTextTypeIsLeftAlone() {
    Defaults[.removeTrailingNewlines] = true
    defer { Defaults.reset(.removeTrailingNewlines) }
    Defaults[.enabledPasteboardTypes] = savedEnabledTypes.subtracting([.html])
    clipboard.onNewCopy({ _ in })
    pasteboard.declareTypes([.string, .html], owner: nil)
    pasteboard.setString("foo\n", forType: .string)
    pasteboard.setString("<b>foo</b><br>", forType: .html)
    clipboard.checkForChangesInPasteboard()
    XCTAssertEqual(pasteboard.string(forType: .string), "foo\n")
    XCTAssertEqual(pasteboard.string(forType: .html), "<b>foo</b><br>")
  }

  func testNewCopyKeepsTrailingNewlinesWhenDisabled() {
    Defaults[.removeTrailingNewlines] = false
    defer { Defaults.reset(.removeTrailingNewlines) }
    clipboard.onNewCopy({ _ in })
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("foo\n", forType: .string)
    clipboard.checkForChangesInPasteboard()
    XCTAssertEqual(pasteboard.string(forType: .string), "foo\n")
  }

  func testIgnoreEventsIsEnabled() {
    Defaults[.ignoreEvents] = true

    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("foo", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreOnlyNextEventIsEnabled() {
    Defaults[.ignoreEvents] = true
    Defaults[.ignoreOnlyNextEvent] = true

    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("foo", forType: .string)
    waitForExpectations(timeout: 2)

    XCTAssertFalse(Defaults[.ignoreEvents])
    XCTAssertFalse(Defaults[.ignoreOnlyNextEvent])
  }

  func testIgnoreApplication() throws {
    Defaults[.ignoredApps] = [try frontmostAppBundleIdentifier()]

    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreAllApplicationsExcept() throws {
    Defaults[.ignoreAllAppsExceptListed] = true
    Defaults[.ignoredApps] = [try frontmostAppBundleIdentifier()]

    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreTransientTypes() {
    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string, transientType], owner: nil)
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreCustomTypes() {
    Defaults[.ignoredPasteboardTypes] = [customType.rawValue]

    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.string, customType], owner: nil)
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testIgnoreCopiesWithUnknownTypes() {
    let hookExpectation = expectation(description: "Hook is called")
    hookExpectation.isInverted = true
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([unknownType], owner: nil)
    pasteboard.setString(" ", forType: unknownType)
    waitForExpectations(timeout: 2)
  }

  func testCopy() {
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
    XCTAssertEqual(pasteboard.string(forType: .string), "foo")
    XCTAssertEqual(pasteboard.data(forType: .tiff), imageData)
    XCTAssertEqual(pasteboard.string(forType: .fileURL), "file://foo.bar")
    XCTAssertEqual(pasteboard.string(forType: .fromMaccy), "")
    XCTAssertEqual(pasteboard.string(forType: .source), "com.foo.bar")
  }

  func testCopyRemovesTrailingNewlines() {
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
    XCTAssertEqual(pasteboard.string(forType: .string), "foo\nbar")
    let rtf = NSAttributedString(rtf: pasteboard.data(forType: .rtf)!, documentAttributes: nil)!
    XCTAssertEqual(rtf.string, "foo\nbar")
    let color = rtf.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
    XCTAssertEqual(color?.usingColorSpace(.sRGB)?.redComponent, 1)
    XCTAssertNil(pasteboard.data(forType: .html))
    // The stored history item keeps its original value.
    XCTAssertEqual(item.contents.first { $0.type == stringType.rawValue }?.value,
                   "foo\nbar\r\n\n".data(using: .utf8)!)
  }

  func testCopyRemovesTrailingNewlinesFromHTMLOnlyRichText() {
    Defaults[.removeTrailingNewlines] = true
    defer { Defaults.reset(.removeTrailingNewlines) }
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = [
      HistoryItemContent(type: stringType.rawValue, value: "foo\n".data(using: .utf8)!),
      HistoryItemContent(type: htmlType.rawValue, value: "<b>foo</b><br>".data(using: .utf8)!)
    ]
    clipboard.copy(item)
    XCTAssertEqual(pasteboard.string(forType: .string), "foo")
    XCTAssertNil(pasteboard.data(forType: .html))
    let rtf = NSAttributedString(rtf: pasteboard.data(forType: .rtf)!, documentAttributes: nil)!
    XCTAssertEqual(rtf.string, "foo")
  }

  func testCopyKeepsTrailingNewlinesWhenDisabled() {
    Defaults[.removeTrailingNewlines] = false
    defer { Defaults.reset(.removeTrailingNewlines) }
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = [
      HistoryItemContent(type: stringType.rawValue, value: "foo\n".data(using: .utf8)!),
      HistoryItemContent(type: htmlType.rawValue, value: "<p>foo</p>".data(using: .utf8)!)
    ]
    clipboard.copy(item)
    XCTAssertEqual(pasteboard.string(forType: .string), "foo\n")
    XCTAssertNotNil(pasteboard.data(forType: .html))
  }

  func testCopyWithoutTrailingNewlinesLeavesOtherTextAlone() {
    Defaults[.removeTrailingNewlines] = true
    defer { Defaults.reset(.removeTrailingNewlines) }
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = [
      HistoryItemContent(type: stringType.rawValue, value: "\nfoo  ".data(using: .utf8)!),
      HistoryItemContent(type: htmlType.rawValue, value: "<p>foo</p>".data(using: .utf8)!)
    ]
    clipboard.copy(item)
    XCTAssertEqual(pasteboard.string(forType: .string), "\nfoo  ")
    XCTAssertNotNil(pasteboard.data(forType: .html))
  }

  func testCopyString() {
    clipboard.copyInMaccy("foo")
    XCTAssertEqual(pasteboard.string(forType: .string), "foo")
    XCTAssertEqual(pasteboard.string(forType: .source), NSPasteboard.PasteboardType.fromMaccy.rawValue)
  }

  func testCopyWithoutFormatting() {
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
    XCTAssertEqual(pasteboard.string(forType: .string), "foo")
    XCTAssertEqual(pasteboard.string(forType: .fromMaccy), "")
    XCTAssertEqual(pasteboard.string(forType: .source), "com.foo.bar")
    XCTAssertEqual(pasteboard.string(forType: .fileURL), "file://foo.bar")
    XCTAssertNil(pasteboard.data(forType: .rtf))
  }

  func testHandlesItemsWithoutData() {
    let hookExpectation = expectation(description: "Hook is called")
    pasteboard.clearContents()
    clipboard.onNewCopy({ (_: HistoryItem) in
      hookExpectation.fulfill()
    })
    clipboard.start()
    pasteboard.declareTypes([.fileURL, .string], owner: nil)
    // fileURL is left without data
    pasteboard.setString("bar", forType: .string)
    waitForExpectations(timeout: 2)
  }

  func testMergesMultipleItems() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (item: HistoryItem) in
      XCTAssertEqual(
        Set(item.contents.map({ $0.type })),
        Set([self.tiffType.rawValue, self.stringType.rawValue])
      )
      hookExpectation.fulfill()
    })

    let item1 = NSPasteboardItem()
    item1.setString("foo", forType: .string)
    let item2 = NSPasteboardItem()
    item2.setData(image.tiffRepresentation!, forType: .tiff)

    clipboard.start()
    pasteboard.clearContents()
    pasteboard.writeObjects([item1, item2])

    waitForExpectations(timeout: 2)
  }

  func testDropsTIFFWhenPNGPresent() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (item: HistoryItem) in
      XCTAssertEqual(item.contents.map({ $0.type }), [NSPasteboard.PasteboardType.png.rawValue])
      hookExpectation.fulfill()
    })

    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let item = NSPasteboardItem()
    item.setData(bitmap.representation(using: .png, properties: [:])!, forType: .png)
    item.setData(bitmap.tiffRepresentation!, forType: .tiff)

    clipboard.start()
    pasteboard.clearContents()
    pasteboard.writeObjects([item])

    waitForExpectations(timeout: 2)
  }

  func testCopyOffersTIFFFromPNG() {
    let png = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = [HistoryItemContent(type: NSPasteboard.PasteboardType.png.rawValue, value: png)]
    clipboard.copy(item)
    XCTAssertEqual(pasteboard.data(forType: .png), png)
    let tiff = pasteboard.data(forType: .tiff)
    XCTAssertNotNil(tiff)
    XCTAssertEqual(
      tiff.flatMap(NSBitmapImageRep.init(data:))?.pixelsWide,
      NSBitmapImageRep(data: png)?.pixelsWide
    )
  }

  func testRemovesDisabledTypes() {
    Defaults[.enabledPasteboardTypes] = [.fileURL]

    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (item: HistoryItem) in
      XCTAssertEqual(item.contents.map({ $0.type }), [self.fileURLType.rawValue])
      hookExpectation.fulfill()
    })

    let item = NSPasteboardItem()
    item.setString("foo", forType: .string)
    item.setData(image.tiffRepresentation!, forType: .tiff)
    item.setData("file://foo.bar".data(using: .utf8)!, forType: .fileURL)

    clipboard.start()
    pasteboard.clearContents()
    pasteboard.writeObjects([item])

    waitForExpectations(timeout: 2)
  }

  func testRemovesDynamicTypes() {
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (item: HistoryItem) in
      XCTAssertEqual(item.contents.map({ $0.type }), [self.stringType.rawValue])
      hookExpectation.fulfill()
    })

    let item = NSPasteboardItem()
    item.setString("foo", forType: .string)
    item.setData("".data(using: .utf8)!, forType: dynamicType)

    clipboard.start()
    pasteboard.clearContents()
    pasteboard.writeObjects([item])

    waitForExpectations(timeout: 2)
  }

  func testDoesNotStoreSafariWebArchive() {
    let webArchive = NSPasteboard.PasteboardType.safariWebArchve
    let hookExpectation = expectation(description: "Hook is called")
    clipboard.onNewCopy({ (item: HistoryItem) in
      XCTAssertEqual(Set(item.contents.map(\.type)), [self.stringType.rawValue])
      hookExpectation.fulfill()
    })

    let item = NSPasteboardItem()
    item.setString("hello from safari", forType: .string)
    item.setData(Data(repeating: 0x61, count: 1024 * 1024), forType: webArchive)

    clipboard.start()
    pasteboard.clearContents()
    pasteboard.writeObjects([item])

    waitForExpectations(timeout: 2)
  }

  private func frontmostAppBundleIdentifier() throws -> String {
    guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
      throw XCTSkip("No frontmost application to attribute a copy to")
    }

    return bundleIdentifier
  }
}
// swiftlint:enable type_body_length
