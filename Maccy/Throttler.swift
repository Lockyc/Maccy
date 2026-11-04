import Foundation

// Based on https://www.craftappco.com/blog/2018/5/30/simple-throttling-in-swift.
class Throttler {
  var minimumDelay: TimeInterval

  private var workItem: DispatchWorkItem = DispatchWorkItem(block: {})
  private var previousRun: Date = Date.distantPast
  private let queue: DispatchQueue

  init(minimumDelay: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
    self.minimumDelay = minimumDelay
    self.queue = queue
  }

  func throttle(_ block: @escaping () -> Void) {
    // Cancel any existing work item if it has not yet executed
    cancel()

    // Re-assign workItem with the new block task,
    // resetting the previousRun time when it executes
    workItem = DispatchWorkItem { [weak self] in
      self?.previousRun = Date()
      block()
    }

    // Run at once when the previous run is at least minimumDelay ago,
    // otherwise as soon as it will be.
    let delay = max(0, minimumDelay - Date().timeIntervalSince(previousRun))
    queue.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  func cancel() {
    workItem.cancel()
  }
}
