import AppKit
import Testing
import Defaults
import SwiftData
@testable import Maccy

extension SharedStateTests {
  @MainActor
  final class HistoryTests { // swiftlint:disable:this type_body_length
    let savedSize = Defaults[.size]
    let savedSortBy = Defaults[.sortBy]
    let savedPinOrder = Defaults[.pinOrder]
    let savedPinTo = Defaults[.pinTo]
    let history = History.shared

    init() {
      History.shared.clearAll()
      Defaults[.size] = 10
      Defaults[.sortBy] = .firstCopiedAt
      Defaults[.pinOrder] = PinOrder()
      Defaults[.pinTo] = .bottom
    }

    deinit {
      Defaults[.size] = savedSize
      Defaults[.sortBy] = savedSortBy
      Defaults[.pinOrder] = savedPinOrder
      Defaults[.pinTo] = savedPinTo
    }

    @Test("Default is empty")
    func defaultIsEmpty() {
      #expect(history.items.toArray() == [])
    }

    @Test("Adding")
    func adding() {
      let first = history.add(historyItem("foo"))
      let second = history.add(historyItem("bar"))
      #expect(history.items.toArray() == [second, first])
    }

    @Test("Newest item is the last copied, across sort order and pins")
    func newestItem() {
      let old = historyItem("old")
      old.lastCopiedAt = Date(timeIntervalSinceReferenceDate: 1)
      let pinned = historyItem("pinned")
      pinned.lastCopiedAt = Date(timeIntervalSinceReferenceDate: 2)
      let recopied = historyItem("recopied")
      recopied.firstCopiedAt = Date(timeIntervalSinceReferenceDate: 0)
      recopied.lastCopiedAt = Date(timeIntervalSinceReferenceDate: 3)
      history.add(old)
      history.togglePin(history.add(pinned))
      let newest = history.add(recopied)

      #expect(history.firstUnpinnedItem != newest)
      #expect(history.newestItem == newest)
    }

    @Test("Adding persisted duplicate")
    func addingPersistedDuplicate() throws {
      let first = historyItem("foo")
      first.title = "xyz"
      first.application = "iTerm.app"
      history.add(first)
      first.pin = "f"

      let third = historyItem("foo")
      third.application = "Xcode.app"
      let transferredContents = first.contents
      let merged = history.add(third)

      #expect(history.items.toArray() == [merged])
      #expect(Set(merged.item.contents) == Set(transferredContents))
      #expect(merged.item.lastCopiedAt > merged.item.firstCopiedAt)
      #expect(merged.item.numberOfCopies == 2)
      #expect(merged.item.pin == "f")
      #expect(merged.item.title == "xyz")
      #expect(merged.item.application == "iTerm.app")
      try assertStorageCounts(items: 1, contents: 1)
    }

    @Test("Adding unsaved duplicate")
    @available(macOS 15.0, *)
    func addingUnsavedDuplicate() throws {
      let first = historyItem("foo")
      first.title = "xyz"
      first.application = "iTerm.app"
      history.add(first)
      first.pin = "f"

      let second = historyItem("foo", persisted: false)
      second.application = "Xcode.app"
      let transferredContents = first.contents
      let merged = history.add(second)

      #expect(history.items.toArray() == [merged])
      #expect(Set(merged.item.contents) == Set(transferredContents))
      #expect(merged.item.lastCopiedAt > merged.item.firstCopiedAt)
      #expect(merged.item.numberOfCopies == 2)
      #expect(merged.item.pin == "f")
      #expect(merged.item.title == "xyz")
      #expect(merged.item.application == "iTerm.app")
      try assertStorageCounts(items: 1, contents: 1)
    }

    @Test("Adding item that is superseded by existing")
    func addingItemThatIsSupersededByExisting() throws {
      let firstContents = [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: "one".data(using: .utf8)!
        ),
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.rtf.rawValue,
          value: "two".data(using: .utf8)!
        )
      ]
      let firstItem = HistoryItem()
      Storage.shared.context.insert(firstItem)
      firstItem.application = "Maccy.app"
      firstItem.contents = firstContents
      firstItem.title = firstItem.generateTitle()
      history.add(firstItem)

      let secondContents = [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: "one".data(using: .utf8)!
        )
      ]
      let secondItem = HistoryItem()
      Storage.shared.context.insert(secondItem)
      secondItem.application = "Maccy.app"
      secondItem.contents = secondContents
      secondItem.title = secondItem.generateTitle()
      let second = history.add(secondItem)

      #expect(history.items.toArray() == [second])
      #expect(Set(history.items[0].item.contents) == Set(firstContents))
      try assertStorageCounts(items: 1, contents: firstContents.count)
    }

    @Test("Adding item with different modified type")
    func addingItemWithDifferentModifiedType() {
      let firstContents = [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: "one".data(using: .utf8)!
        ),
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.modified.rawValue,
          value: "1".data(using: .utf8)!
        )
      ]
      let firstItem = HistoryItem()
      Storage.shared.context.insert(firstItem)
      firstItem.contents = firstContents
      history.add(firstItem)

      let secondContents = [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: "one".data(using: .utf8)!
        ),
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.modified.rawValue,
          value: "2".data(using: .utf8)!
        )
      ]
      let secondItem = HistoryItem()
      Storage.shared.context.insert(secondItem)
      secondItem.contents = secondContents
      let second = history.add(secondItem)

      #expect(history.items.toArray() == [second])
      #expect(Set(history.items[0].item.contents) == Set(firstContents))
    }

    @Test("Adding item from Maccy")
    func addingItemFromMaccy() {
      let firstContents = [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: "one".data(using: .utf8)
        )
      ]
      let first = HistoryItem()
      Storage.shared.context.insert(first)
      first.application = "Xcode.app"
      first.contents = firstContents
      history.add(first)

      let secondContents = [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: "one".data(using: .utf8)
        ),
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.fromMaccy.rawValue,
          value: "".data(using: .utf8)
        )
      ]
      let second = HistoryItem()
      Storage.shared.context.insert(second)
      second.application = "Maccy.app"
      second.contents = secondContents
      let secondDecorator = history.add(second)

      #expect(history.items.toArray() == [secondDecorator])
      #expect(history.items[0].item.application == "Xcode.app")
      #expect(Set(history.items[0].item.contents) == Set(firstContents))
    }

    @Test("Modified after copying")
    func modifiedAfterCopying() {
      history.add(historyItem("foo"))

      let modifiedItem = historyItem("bar")
      modifiedItem.contents.append(HistoryItemContent(
        type: NSPasteboard.PasteboardType.modified.rawValue,
        value: String(Clipboard.shared.changeCount).data(using: .utf8)
      ))
      let modifiedItemDecorator = history.add(modifiedItem)

      #expect(history.items.toArray() == [modifiedItemDecorator])
      #expect(history.items[0].text == "bar")
    }

    @Test("Clearing unpinned")
    func clearingUnpinned() throws {
      let pinned = history.add(historyItem("foo"))
      history.togglePin(pinned)
      history.add(historyItem("bar"))
      let orphan = HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "orphan".data(using: .utf8)
      )
      Storage.shared.context.insert(orphan)
      try Storage.shared.context.save()

      history.clear()

      #expect(history.items.toArray() == [pinned])
      try assertStorageCounts(items: 1, contents: 1)
    }

    @Test("Clearing all")
    func clearingAll() throws {
      history.add(historyItem("foo"))
      let pinned = history.add(historyItem("bar"))
      history.togglePin(pinned)
      Storage.shared.context.insert(HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "orphan".data(using: .utf8)
      ))
      try Storage.shared.context.save()

      history.clearAll()

      #expect(history.items.toArray() == [])
      try assertStorageCounts(items: 0, contents: 0)
    }

    @Test("Max size")
    func maxSize() throws {
      var items: [HistoryItemDecorator] = []
      for index in 0...10 {
        items.append(history.add(historyItem(String(index))))
      }

      #expect(history.items.count == 10)
      #expect(history.items.contains(items[10]))
      #expect(!history.items.contains(items[0]))
      try assertStorageCounts(items: 10, contents: 10)
    }

    @Test("Max size ignores pinned")
    func maxSizeIgnoresPinned() {
      var items: [HistoryItemDecorator] = []

      let item = history.add(historyItem("0"))
      items.append(item)
      history.togglePin(item)

      for index in 1...11 {
        items.append(history.add(historyItem(String(index))))
      }

      #expect(history.items.count == 11)
      #expect(history.items.contains(items[10]))
      #expect(history.items.contains(items[0]))
      #expect(!history.items.contains(items[1]))
    }

    @Test("Pinning updates pin order")
    func pinningUpdatesPinOrder() {
      let item = history.add(historyItem("foo"))
      history.togglePin(item)

      #expect(history.pinnedItems == [item])
      #expect(Defaults[.pinOrder].pins == [item.item.pin].compactMap { $0 })
    }

    @Test("Pins without a free key get no shortcuts")
    func noShortcutsForPinWithoutKey() {
      #expect(KeyShortcut.create(character: "").isEmpty)
      #expect(KeyShortcut.create(character: "b").count == 3)
    }

    @Test("Pinning after all shortcuts are assigned")
    func pinningAfterAllShortcutsAreAssigned() async throws {
      let supportedPins = HistoryItem.supportedPins
      for index in 0..<supportedPins.count {
        let item = history.add(historyItem("keyed \(index)"))
        history.togglePin(item)
      }

      #expect(history.availablePins.isEmpty)
      #expect(Set(history.pinnedItems.compactMap(\.item.pin)) == supportedPins)

      let first = history.add(historyItem("first without shortcut"))
      history.togglePin(first)
      let second = history.add(historyItem("second without shortcut"))
      history.togglePin(second)

      #expect(first.item.pin == "")
      #expect(second.item.pin == "")
      #expect(history.pinnedItems.suffix(2) == [first, second])
      #expect(history.unpinnedItems.isEmpty)

      for index in 0...Defaults[.size] {
        history.add(historyItem("unpinned \(index)"))
      }

      let expectedCount = supportedPins.count + 2
      #expect(history.pinnedItems.count == expectedCount)
      try assertStorageCounts(
        items: expectedCount + Defaults[.size],
        contents: expectedCount + Defaults[.size]
      )

      try await history.load()
      #expect(history.pinnedItems.count == expectedCount)
      #expect(
        Set(history.pinnedItems.filter { $0.item.pin == "" }.map(\.title)) ==
        ["first without shortcut", "second without shortcut"]
      )
    }

    @Test("Unpinning updates pin order")
    func unpinningUpdatesPinOrder() {
      let item = history.add(historyItem("foo"))
      history.togglePin(item)
      history.togglePin(item)

      #expect(history.pinnedItems == [])
      #expect(Defaults[.pinOrder].pins == [])
    }

    @Test("Moving pins updates pin order")
    func movingPinsUpdatesPinOrder() {
      let first = history.add(historyItem("foo"))
      let second = history.add(historyItem("bar"))
      history.togglePin(first)
      history.togglePin(second)

      history.movePin(from: IndexSet(integer: 0), to: 2)

      #expect(history.pinnedItems == [second, first])
      #expect(Defaults[.pinOrder].pins == [second.item.pin, first.item.pin].compactMap { $0 })
    }

    @Test("Max size is changed")
    func maxSizeIsChanged() {
      var items: [HistoryItemDecorator] = []
      for index in 0...10 {
        items.append(history.add(historyItem(String(index))))
      }
      Defaults[.size] = 5
      history.add(historyItem("11"))

      #expect(history.items.count == 5)
      #expect(history.items.contains(items[10]))
      #expect(!history.items.contains(items[5]))
    }

    @Test("Re-adding bottom-most pinned item at full capacity")
    func readdingBottomMostPinnedItemAtFullCapacity() {
      // Regression test for a crash when re-copying (invoking) the bottom-most
      // pinned item while history is at full capacity and pins are sorted to the
      // bottom. The stale insert index used to trap with an out-of-bounds insert.
      // Issue link: https://github.com/p0deje/Maccy/issues/1466
      // `pinTo` is restored to its default value(.top) in `deinit`.
      Defaults[.pinTo] = .bottom

      // Pin an item; `history.togglePin` re-sorts `all`, so with `.bottom` the
      // pinned item ends up as the last element.
      let pinned = history.add(historyItem("pinned"))
      history.togglePin(pinned)

      // Fill unpinned history to full capacity.
      for index in 0..<Defaults[.size] {
        history.add(historyItem(String(index)))
      }

      #expect(history.items.last == pinned)

      // Re-copy the pinned item. It is detected as a duplicate, removed and
      // re-inserted while `limitHistorySize` trims an exceeding unpinned item.
      // Before the fix this inserted at a stale, out-of-bounds index and crashed.
      let readded = history.add(historyItem("pinned"))

      #expect(history.items.contains(readded))
      #expect(history.items.filter(\.isPinned).count == 1)
    }

    @Test("Removing")
    func removing() throws {
      let foo = history.add(historyItem("foo"))
      let bar = history.add(historyItem("bar"))
      history.delete(foo)
      #expect(history.items.toArray() == [bar])
      try assertStorageCounts(items: 1, contents: 1)
    }

    @Test("Cleaning up orphaned contents")
    func cleaningUpOrphanedContents() throws {
      let live = history.add(historyItem("live"))
      let liveContent = live.item.contents[0]
      for value in ["orphan-1", "orphan-2"] {
        Storage.shared.context.insert(HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: value.data(using: .utf8)
        ))
      }
      try Storage.shared.context.save()

      #expect(try Storage.shared.cleanupOrphanedContents() == 2)
      #expect(try Storage.shared.cleanupOrphanedContents() == 0)
      #expect(live.item.contents == [liveContent])
      try assertStorageCounts(items: 1, contents: 1)
    }

    @Test("Removing unpersistable contents")
    func removingUnpersistableContents() throws {
      let live = history.add(historyItem("live"))
      live.item.contents.append(HistoryItemContent(
        type: NSPasteboard.PasteboardType.safariWebArchve.rawValue,
        value: Data(repeating: 0x61, count: 1024)
      ))
      try Storage.shared.context.save()

      #expect(try Storage.shared.removeUnpersistableContents() == 1)
      #expect(try Storage.shared.removeUnpersistableContents() == 0)
      #expect(live.item.contents.map(\.type) == [NSPasteboard.PasteboardType.string.rawValue])
      try assertStorageCounts(items: 1, contents: 1)
    }

    @Test("Removing redundant TIFFs")
    func removingRedundantTIFFs() throws {
      let png = NSPasteboard.PasteboardType.png.rawValue
      let tiff = NSPasteboard.PasteboardType.tiff.rawValue
      let both = history.add(historyItem("both"))
      both.item.contents.append(HistoryItemContent(type: png, value: Data(repeating: 0x1, count: 16)))
      both.item.contents.append(HistoryItemContent(type: tiff, value: Data(repeating: 0x2, count: 64)))
      let tiffOnly = history.add(historyItem("tiff-only"))
      tiffOnly.item.contents.append(HistoryItemContent(type: tiff, value: Data(repeating: 0x3, count: 64)))
      try Storage.shared.context.save()

      #expect(try Storage.shared.removeRedundantTIFFs() == 1)
      #expect(try Storage.shared.removeRedundantTIFFs() == 0)
      #expect(Set(both.item.contents.map(\.type)) == [NSPasteboard.PasteboardType.string.rawValue, png])
      #expect(Set(tiffOnly.item.contents.map(\.type)) == [NSPasteboard.PasteboardType.string.rawValue, tiff])
      try assertStorageCounts(items: 2, contents: 4)
    }

    @Test("Moving contents to external storage keeps values")
    func movingContentsToExternalStorageKeepsValues() throws {
      let item = history.add(historyItem("kept"))
      try Storage.shared.context.save()

      let original = item.item.contents
      #expect(try Storage.shared.moveContentsToExternalStorage() == 1)
      #expect(item.item.text == "kept")
      #expect(item.item.contents != original)
      try assertStorageCounts(items: 1, contents: 1)
    }

    @Test("Clearing keeps a pin made or re-copied since the last save", arguments: [0, 1, 2])
    func clearingKeepsUnsavedPin(recopies: Int) async throws {
      let pinned = history.add(historyItem("pinned"))
      history.add(historyItem("unpinned"))
      history.togglePin(pinned)
      for _ in 0..<recopies {
        history.add(historyItem("pinned"))
      }

      history.clear()

      try assertStorageCounts(items: 1, contents: 1)
      try await history.load()
      #expect(history.pinnedItems.map(\.item.text) == ["pinned"])
      #expect(history.unpinnedItems.isEmpty)
    }

    // "unsaved" is an item inserted into the context but neither saved nor listed.
    @Test("A removed image item stays removed once its text is recognized",
          arguments: ["delete", "clear", "clearAll", "unsaved"])
    func removedImageStaysRemovedAfterOCR(removal: String) async throws {
      let image = NSImage(size: NSSize(width: 360, height: 100), flipped: false) { rect in
        NSColor.white.setFill()
        rect.fill()
        NSAttributedString(string: "Removed", attributes: [.font: NSFont.boldSystemFont(ofSize: 48)])
          .draw(at: NSPoint(x: 20, y: 20))
        return true
      }
      let item = HistoryItem()
      Storage.shared.context.insert(item)
      let tiff = NSPasteboard.PasteboardType.tiff.rawValue
      item.contents = [HistoryItemContent(type: tiff, value: image.tiffRepresentation)]
      item.numberOfCopies = 1
      item.title = item.generateTitle()
      switch removal {
      case "delete":
        history.delete(history.add(item))
      case "clear":
        history.add(item)
        history.clear()
      case "clearAll":
        history.add(item)
        history.clearAll()
      default:
        history.clearAll()
      }
      try assertStorageCounts(items: 0, contents: 0)

      let deadline = ContinuousClock.now + .seconds(60)
      while item.title.isEmpty && ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(100))
      }
      try #require(item.title == "Removed")
      try assertStorageCounts(items: 0, contents: 0)
    }

    // A seed that once failed goes in `regressionSeeds`, so it runs on every pass.
    static let regressionSeeds: [UInt64] = []

    @Test("Seeded command sequences keep pins, shortcuts and contents consistent")
    func seededCommandSequences() async throws {
      Defaults[.sortBy] = .lastCopiedAt
      var model = HistoryModel()

      // Leave two free pin keys, so pins run out of keys within a sequence.
      let fillerCount = HistoryItem.supportedPins.count - 2
      for index in 0..<fillerCount {
        let filler = history.add(timedItem("filler \(index)", model: &model))
        history.togglePin(filler)
        model.pinned.append((text: "filler \(index)", key: filler.item.pin ?? "?"))
      }
      model.fillers = model.pinned.count
      await mainQueueTurn()

      for seed in Self.regressionSeeds + (0..<100).map(UInt64.init) {
        let failures = try await runSequence(seed: seed, steps: 30, model: &model)
        guard failures.isEmpty else {
          Issue.record("\(failures.joined(separator: "\n"))")
          return
        }
      }
    }

    // Runs one sequence from `model`'s current state, then removes the items it added.
    // Stops at the first step whose state breaks an invariant and returns what broke,
    // with the seed and the steps that led there.
    private func runSequence(seed: UInt64, steps: Int, model: inout HistoryModel) async throws -> [String] {
      var rng = SplitMix64(seed: seed)
      var log: [String] = []
      model.size = 4
      Defaults[.size] = model.size
      let pool = (0..<6).map { "value \($0)" }

      for _ in 0..<steps {
        let ownTexts = model.unpinned + model.pinned.dropFirst(model.fillers).map(\.text)
        let target = ownTexts.isEmpty ? nil : ownTexts[Int(rng.next() % UInt64(ownTexts.count))]
        var failures: [String] = []
        var afterAdd = false
        var pinned = false

        switch rng.next() % 10 {
        case 0...3:
          let text = pool[Int(rng.next() % UInt64(pool.count))]
          log.append("add \(text)")
          history.add(timedItem(text, model: &model))
          model.add(text)
          afterAdd = true
        case 4, 5:
          guard let target else { continue }
          let wasPinned = model.pinned.contains { $0.text == target }
          let freeKeys = Set(history.availablePins)
          log.append("togglePin \(target)")
          let decorator = try #require(history.items.first { $0.item.text == target })
          history.togglePin(decorator)
          if wasPinned {
            model.unpin(target)
          } else {
            let key = decorator.item.pin ?? "?"
            if freeKeys.isEmpty ? key != "" : !freeKeys.contains(key) {
              failures.append("pin took key '\(key)' with free keys \(freeKeys.sorted())")
            }
            model.pin(target, key: key)
            pinned = true
          }
        case 6:
          guard let target else { continue }
          log.append("delete \(target)")
          history.delete(history.items.first { $0.item.text == target })
          model.delete(target)
        case 7:
          log.append("delete first unpinned")
          history.delete(history.firstUnpinnedItem)
          if let first = model.unpinned.first { model.delete(first) }
        case 8:
          model.size = Int(rng.next() % 6) + 1
          log.append("size \(model.size)")
          Defaults[.size] = model.size
        default:
          log.append("clear")
          history.clear()
          model.unpinned = []
        }

        if pinned {
          await mainQueueTurn()
        }
        failures += try brokenInvariants(model, afterAdd: afterAdd)
        if !failures.isEmpty {
          return failures + ["seed \(seed), steps: \(log.joined(separator: "; "))"]
        }
      }

      for text in model.unpinned + model.pinned.dropFirst(model.fillers).map(\.text) {
        history.delete(history.items.first { $0.item.text == text })
      }
      model.unpinned = []
      model.pinned.removeLast(model.pinned.count - model.fillers)
      return []
    }

    private func brokenInvariants(_ model: HistoryModel, afterAdd: Bool) throws -> [String] {
      var broken: [String] = []
      func check(_ condition: Bool, _ message: @autoclosure () -> String) {
        if !condition { broken.append(message()) }
      }
      let unpinned = history.unpinnedItems
      let pinned = history.pinnedItems

      check(unpinned.map(\.item.text) == model.unpinned.map(Optional.init),
            "unpinned \(unpinned.map(\.item.text)) != model \(model.unpinned)")
      check(pinned.map(\.item.text) == model.pinned.map { Optional($0.text) },
            "pinned \(pinned.map(\.item.text)) != model \(model.pinned.map(\.text))")
      check(pinned.map(\.item.pin) == model.pinned.map { Optional($0.key) },
            "pin keys \(pinned.map(\.item.pin)) != model \(model.pinned.map(\.key))")
      if afterAdd {
        check(unpinned.count <= model.size, "\(unpinned.count) unpinned over size \(model.size)")
      }

      for (index, item) in unpinned.enumerated() {
        let expected = index < 9 ? shortcutKeys(KeyShortcut.create(character: String(index + 1))) : []
        check(shortcutKeys(item.shortcuts) == expected, "unpinned #\(index + 1) has \(shortcutKeys(item.shortcuts))")
      }
      for item in pinned {
        let pin = item.item.pin ?? ""
        check(shortcutKeys(item.shortcuts) == shortcutKeys(KeyShortcut.create(character: pin)),
              "pin '\(pin)' has \(shortcutKeys(item.shortcuts))")
      }
      let allShortcuts = history.items.flatMap { shortcutKeys($0.shortcuts) }
      check(Set(allShortcuts).count == allShortcuts.count, "two items share a shortcut: \(allShortcuts)")

      // No save here: a save between commands would hide state that only goes wrong unsaved.
      let context = Storage.shared.context
      let storedItems = try context.fetch(FetchDescriptor<HistoryItem>())
      check(storedItems.count == history.items.count,
            "stored items \(storedItems.map(\.title)) differ from the list's \(history.items.map(\.title))")
      for item in history.items {
        check(!item.item.contents.isEmpty, "'\(item.title)' has no contents")
        for content in item.item.contents {
          check(!content.isDeleted && content.modelContext != nil && content.item === item.item,
                "'\(item.title)' lists a detached content")
        }
      }
      check(try Storage.shared.cleanupOrphanedContents() == 0, "orphaned contents left in storage")

      return broken
    }

    @Test("Seeded selection commands keep the lead item selected and in the list")
    func seededSelectionSequences() throws {
      let savedOpenPreview = Defaults[.openPreviewAutomatically]
      Defaults[.openPreviewAutomatically] = false
      defer { Defaults[.openPreviewAutomatically] = savedOpenPreview }
      let appState = AppState.shared
      let navigator = appState.navigator
      let pool = (0..<8).map { "value \($0)" }

      for seed in UInt64(0)..<50 {
        var rng = SplitMix64(seed: seed)
        var log: [String] = []
        navigator.select(item: nil)
        for text in pool.prefix(Int(rng.next() % 6) + 3) where history.items.allSatisfy({ $0.item.text != text }) {
          history.add(historyItem(text))
        }

        for _ in 0..<15 {
          let items = history.items.toArray()
          let target = items.isEmpty ? nil : items[Int(rng.next() % UInt64(items.count))]
          var deletedWithLead = false
          switch rng.next() % 6 {
          case 0:
            guard let target else { continue }
            log.append("select \(target.title)")
            navigator.select(item: target)
          case 1, 2:
            // Half the time an already selected item, which takes it back out of the selection.
            let selected = navigator.selection.items
            let pick = rng.next() % 2 == 0 && !selected.isEmpty
              ? selected[Int(rng.next() % UInt64(selected.count))] : target
            guard let pick else { continue }
            log.append("addToSelection \(pick.title)")
            navigator.addToSelection(item: pick)
          case 3:
            log.append("deleteSelection")
            deletedWithLead = navigator.leadHistoryItem != nil
            appState.deleteSelection()
          default:
            log.append("togglePin selection")
            appState.togglePin()
          }

          let context = "seed \(seed), steps: \(log.joined(separator: "; "))"
          let listed = history.items.toArray()
          let selected = navigator.selection.items
          if let lead = navigator.leadHistoryItem {
            #expect(selected.contains(lead), "lead item is not selected; \(context)")
            #expect(listed.contains(lead), "lead item is not in the list; \(context)")
          }
          #expect(selected.allSatisfy(listed.contains), "a selected item is not in the list; \(context)")
          #expect(
            selected.enumerated().allSatisfy { $0.element.selectionIndex == $0.offset },
            "selection indexes out of step; \(context)"
          )
          #expect(
            Set(listed.filter(\.isSelected).map(\.id)) == Set(selected.map(\.id)),
            "rows marked selected differ from the selection; \(context)"
          )
          if deletedWithLead && !listed.isEmpty {
            #expect(navigator.leadHistoryItem != nil, "nothing selected after deleting with items left; \(context)")
          }
        }
      }
      navigator.select(item: nil)
    }

    // A new pin's shortcuts follow its key one main-queue turn later.
    private func mainQueueTurn() async {
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
      }
    }

    private func shortcutKeys(_ shortcuts: [KeyShortcut]) -> [String] {
      shortcuts.map { "\(String(describing: $0.key))+\($0.modifierFlags.rawValue)" }
    }

    private func timedItem(_ value: String, model: inout HistoryModel) -> HistoryItem {
      model.clock += 1
      model.lastCopied[value] = model.clock
      let item = historyItem(value)
      item.firstCopiedAt = Date(timeIntervalSinceReferenceDate: model.clock)
      item.lastCopiedAt = item.firstCopiedAt
      return item
    }

    private func assertStorageCounts(
      items: Int,
      contents: Int,
      orphaned: Int = 0,
      fileID: String = #fileID,
      filePath: String = #filePath,
      line: Int = #line,
      column: Int = #column
    ) throws {
      let sourceLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
      let context = Storage.shared.context
      context.processPendingChanges()
      try context.save()
      #expect(
        try context.fetchCount(FetchDescriptor<HistoryItem>()) == items,
        sourceLocation: sourceLocation
      )
      #expect(
        try context.fetchCount(FetchDescriptor<HistoryItemContent>()) == contents,
        sourceLocation: sourceLocation
      )
      #expect(
        try context.fetchCount(FetchDescriptor<HistoryItemContent>(
          predicate: #Predicate { $0.item == nil }
        )) == orphaned,
        sourceLocation: sourceLocation
      )
    }

    private func historyItem(_ value: String, persisted: Bool = true) -> HistoryItem {
      let contents = [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: value.data(using: .utf8)
        )
      ]
      let item = HistoryItem()
      if persisted {
        Storage.shared.context.insert(item)
      }
      item.contents = contents
      item.numberOfCopies = 1
      item.title = item.generateTitle()

      return item
    }
  }
}

// What History's lists should hold after each command of a sequence, with pins at the bottom
// and unpinned items sorted by last copy.
private struct HistoryModel {
  var unpinned: [String] = []
  var pinned: [(text: String, key: String)] = []
  var fillers = 0
  var size = 4
  var clock: TimeInterval = 0
  var lastCopied: [String: TimeInterval] = [:]

  mutating func add(_ text: String) {
    if pinned.contains(where: { $0.text == text }) {
      unpinned = Array(unpinned.prefix(size))
      return
    }
    unpinned.removeAll { $0 == text }
    unpinned = Array(unpinned.prefix(size - 1))
    unpinned.insert(text, at: 0)
  }

  // A pin with a key sorts after the other keyed pins; one without sorts last.
  mutating func pin(_ text: String, key: String) {
    unpinned.removeAll { $0 == text }
    let index = key.isEmpty ? pinned.count : (pinned.lastIndex { !$0.key.isEmpty }.map { $0 + 1 } ?? 0)
    pinned.insert((text: text, key: key), at: index)
  }

  mutating func unpin(_ text: String) {
    pinned.removeAll { $0.text == text }
    let copied = lastCopied[text] ?? 0
    let index = unpinned.firstIndex { (lastCopied[$0] ?? 0) < copied } ?? unpinned.count
    unpinned.insert(text, at: index)
  }

  mutating func delete(_ text: String) {
    unpinned.removeAll { $0 == text }
    pinned.removeAll { $0.text == text }
  }
}

private struct SplitMix64: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) { state = seed }

  mutating func next() -> UInt64 {
    state &+= 0x9E3779B97F4A7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
    value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
    return value ^ (value >> 31)
  }
}
