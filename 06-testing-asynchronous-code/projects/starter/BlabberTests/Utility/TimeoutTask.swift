//
//  TimeoutTask.swift
//  BlabberTests
//
//  Created by Rohan Bhale on 28/04/24.
//

import Foundation

class TimeoutTask<Success> {
  let seconds: Int
  let operation: @Sendable () async throws -> Success
  var continuation: CheckedContinuation<Success, Error>?

  init(seconds: Int, operation: @escaping @Sendable () async -> Success) {
    self.seconds = seconds
    self.operation = operation
  }

  var value: Success {
    get async throws {
      try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        Task {
          try await Task.sleep(for:.seconds(seconds))
          self.continuation?.resume(throwing: TimeoutError())
          self.continuation = nil
        }
        Task {
          let result = try await self.operation()
          self.continuation?.resume(returning: result)
          self.continuation = nil
        }
      }
    }
  }

  func cancel() {
    continuation?.resume(throwing: CancellationError())
    continuation = nil
  }
}

extension TimeoutTask {
  struct TimeoutError: LocalizedError {
    var errorDescription: String? {
      "The task timed out."
    }
  }
}
