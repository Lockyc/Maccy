import Foundation
import SwiftData

@Model
class HistoryItemContent {
  var type: String = ""
  // Kept out of the row so faulting a content (e.g. to read `type`) doesn't load
  // multi-MB image data; it is read from its file only when `value` is accessed.
  @Attribute(.externalStorage) var value: Data?

  @Relationship
  var item: HistoryItem?

  init(type: String, value: Data? = nil) {
    self.type = type
    self.value = value
  }
}
