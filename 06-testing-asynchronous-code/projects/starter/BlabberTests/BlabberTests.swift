/// Copyright (c) 2023 Kodeco Inc.
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import XCTest
@testable import Blabber

class BlabberTests: XCTestCase {
  @MainActor
  let model = {
    let model = BlabberModel()
    model.username = "test"
    let config = URLSessionConfiguration.default
    config.protocolClasses = [TestURLProtocol.self]
    let session = URLSession(configuration: config)
    model.urlSession = session
    model.sleep = {
      try await Task.sleep(for: .nanoseconds($0))
    }
    return model
  }()

  func testModelSay() async throws {
    try await model.say("Hello!")
    let request = try XCTUnwrap(TestURLProtocol.lastRequest)
    XCTAssertEqual(request.url?.absoluteString, "http://localhost:8080/chat/say")
    let httpBody = try XCTUnwrap(request.httpBody)
    let message = try XCTUnwrap(try? JSONDecoder().decode(Message.self, from: httpBody))
    XCTAssertEqual(message.message, "Hello!")
  }

  func testModelCountDown() async throws {
    // Three important things to note
    // - (1/3)Two task run in parallel the model.countdown(to:) and the TimeoutTask
    // - The TimeoutTask operation generates an array of String
    //   (2/3)It limits the infinite stream of URLRequest to 4 by using prefix(4)
    //   (3/3)The reduce method actually creates an iterator and generates the string array
    // I have also created my version of reduce to demonstrate how the string value is generated in an extension of AsyncSequence below
    async let countdown: Void = try await model.countdown(to: "Hello!")
    async let messages: [String] = TimeoutTask(seconds: 10) {
      // The await is for the request method which produces result asynchronously
      await TestURLProtocol
        .requests // requests is async stream of URLRequest
        .prefix(4) // returns an AsyncPrefixSequence
        .compactMap { $0.httpBody }// returns an AsyncCompactMapSequence
        .compactMap { // return an AsyncCompactMapSequence
          try? JSONDecoder()
            .decode(Message.self, from: $0)
            .message
        }
        .myReduce([]) { $0 + [$1] } // Reduce is where the iterator is created and iteration happens
    }.value

    let (messagesResult, _) = try await (messages, countdown)

    XCTAssertEqual(["3...", "2...", "1...", "🎉 Hello!"], messagesResult)
  }
}


extension AsyncSequence {
  @inlinable public func myReduce<Result>(_ initialResult: Result, _ nextPartialResult: (_ partialResult: Result, Self.Element) async throws -> Result) async rethrows -> Result {
    var result: Result = initialResult
    var iterator = makeAsyncIterator()
    while let element = try await iterator.next() {
      result = try await nextPartialResult(result, element)
    }
    return result
  }
}
