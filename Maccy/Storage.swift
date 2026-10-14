import AppKit.NSPasteboard
import Foundation
import SwiftData

@MainActor
class Storage {
  static let shared = Storage()

  var container: ModelContainer
  var context: ModelContext { container.mainContext }
  var size: String {
    guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).allValues.first?.value as? Int64, size > 1 else {
      return ""
    }

    return ByteCountFormatter().string(fromByteCount: size)
  }

  private let url = URL.applicationSupportDirectory.appending(path: "Maccy/Storage.sqlite")

  init() {
    var config = ModelConfiguration(url: url)

    #if DEBUG
    if AppDelegate.isTesting {
      config = ModelConfiguration(isStoredInMemoryOnly: true)
    }
    #endif

    do {
      container = try ModelContainer(for: HistoryItem.self, configurations: config)
    } catch let error {
      fatalError("Cannot load database: \(error.localizedDescription).")
    }
  }

  func cleanupOrphanedContents() throws -> Int {
    let descriptor = FetchDescriptor<HistoryItemContent>(
      predicate: #Predicate { $0.item == nil }
    )
    let count = try context.fetchCount(descriptor)
    guard count > 0 else {
      return 0
    }

    try context.delete(
      model: HistoryItemContent.self,
      where: #Predicate { $0.item == nil }
    )
    context.processPendingChanges()
    try context.save()

    return count
  }

  func removeUnpersistableContents() throws -> Int {
    let contents = try context.fetch(FetchDescriptor<HistoryItemContent>())
    let unwanted = contents.filter {
      !Clipboard.shared.isPersistable(NSPasteboard.PasteboardType($0.type))
    }

    guard !unwanted.isEmpty else {
      return 0
    }

    unwanted.forEach(context.delete)
    context.processPendingChanges()
    try context.save()

    return unwanted.count
  }

  // Clipboard capture skips a TIFF that comes with a PNG of the same image; this
  // drops the ones stored before it did.
  func removeRedundantTIFFs() throws -> Int {
    let tiff = NSPasteboard.PasteboardType.tiff.rawValue
    let png = NSPasteboard.PasteboardType.png.rawValue
    let tiffs = try context.fetch(FetchDescriptor<HistoryItemContent>(predicate: #Predicate { $0.type == tiff }))
    let redundant = tiffs.filter { $0.item?.contents.contains { $0.type == png } == true }

    guard !redundant.isEmpty else {
      return 0
    }

    for content in redundant {
      content.item?.contents.removeAll { $0 == content }
      context.delete(content)
    }
    context.processPendingChanges()
    try context.save()

    return redundant.count
  }

  // `HistoryItemContent.value` moved to external storage; values written before
  // stay inline in the row. Core Data skips writing a value equal to the stored
  // one, so each content is replaced by a fresh copy rather than reassigned.
  func moveContentsToExternalStorage() throws -> Int {
    let contents = try context.fetch(FetchDescriptor<HistoryItemContent>())
    var count = 0

    for content in contents {
      guard let item = content.item, content.value != nil else { continue }
      item.contents.append(HistoryItemContent(type: content.type, value: content.value))
      item.contents.removeAll { $0 == content }
      context.delete(content)
      count += 1
    }

    guard count > 0 else {
      return 0
    }

    context.processPendingChanges()
    try context.save()

    return count
  }

  // Titles stored before the sanitization in `HistoryItem.generateTitle()` may
  // contain scalars that hang CoreText on macOS 26. Such an item makes Maccy
  // spin at 100% CPU on every launch without ever drawing its window, so the
  // store has to be healed before the history is first rendered.
  // See https://github.com/p0deje/Maccy/issues/1520.
  func sanitizeTitles() throws -> Int {
    let items = try context.fetch(FetchDescriptor<HistoryItem>())
    var count = 0

    for item in items where item.title.containsScalarsUnsafeForTitleLayout {
      item.title = item.title.removingScalarsUnsafeForTitleLayout()
      count += 1
    }

    guard count > 0 else {
      return 0
    }

    context.processPendingChanges()
    try context.save()

    return count
  }
}
