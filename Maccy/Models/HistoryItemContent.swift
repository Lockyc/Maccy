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

  // A deleted content, or one whose deletion was saved, can still be listed by an item a
  // view holds on to. Reading `value` then faults it in from external storage, which
  // SwiftData can no longer do, and it aborts the app. A permanent ID with no context means
  // the deletion was saved; a content that was never saved has a temporary ID instead.
  var isGone: Bool {
    isDeleted || (modelContext == nil && persistentModelID.storeIdentifier != nil)
  }
}
