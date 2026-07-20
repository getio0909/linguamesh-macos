import Foundation
@testable import LinguaMeshFeature
import XCTest

@MainActor
final class NativeCoreIntegrationTests: XCTestCase {
    func testRealCoreWrapperStreamsFakeProviderTranslation() async throws {
        let provider = try FakeProviderProcess.start()
        defer { provider.stop() }
        let core = try NativeCoreClient()
        let events = try await core.translate(
            CoreTranslationRequest(
                endpoint: provider.endpoint,
                modelIdentifier: "fake-translator",
                sourceText: "Hello",
                targetLocale: "zh-CN"
            )
        )
        var output = ""
        var terminals = 0
        for try await event in events {
            switch event {
            case let .textDelta(text):
                output.append(text)
            case .completed:
                terminals += 1
            case .cancelled, .failed:
                XCTFail("Expected a completed terminal event.")
            case .started:
                break
            }
        }
        XCTAssertEqual(output, "你好，LinguaMesh！")
        XCTAssertEqual(terminals, 1)
        try await core.shutdown()
    }

    func testRealCoreWrapperCancellationRetainsPartialOutput() async throws {
        let provider = try FakeProviderProcess.start()
        defer { provider.stop() }
        let core = try NativeCoreClient()
        let events = try await core.translate(
            CoreTranslationRequest(
                endpoint: provider.endpoint,
                modelIdentifier: "fake-slow-translator",
                sourceText: "Cancel this stream",
                targetLocale: "zh-CN"
            )
        )
        var output = ""
        var cancelled = 0
        for try await event in events {
            switch event {
            case let .textDelta(text):
                output.append(text)
                if output == text {
                    try await core.cancel()
                }
            case .cancelled:
                cancelled += 1
            case .completed, .failed:
                XCTFail("Expected a cancelled terminal event.")
            case .started:
                break
            }
        }
        XCTAssertFalse(output.isEmpty)
        XCTAssertEqual(cancelled, 1)
        try await core.shutdown()
    }

    func testRealCoreWrapperMapsAuthenticationFailure() async throws {
        let provider = try FakeProviderProcess.start()
        defer { provider.stop() }
        let core = try NativeCoreClient()
        let events = try await core.translate(
            CoreTranslationRequest(
                endpoint: provider.endpoint,
                modelIdentifier: "fake-translator",
                sourceText: "[auth-error]",
                targetLocale: "zh-CN"
            )
        )
        var failureKind: ClientErrorKind?
        var terminals = 0
        for try await event in events {
            switch event {
            case let .failed(kind, _):
                failureKind = kind
                terminals += 1
            case .completed, .cancelled:
                XCTFail("Expected an authentication failure terminal event.")
            case .started, .textDelta:
                break
            }
        }
        XCTAssertEqual(failureKind, .authentication)
        XCTAssertEqual(terminals, 1)
        try await core.shutdown()
    }

    func testConsumerCancellationAllowsImmediateNextTranslation() async throws {
        let provider = try FakeProviderProcess.start()
        defer { provider.stop() }
        let core = try NativeCoreClient()
        let firstEvents = try await core.translate(
            CoreTranslationRequest(
                endpoint: provider.endpoint,
                modelIdentifier: "fake-slow-translator",
                sourceText: "Cancel the consumer",
                targetLocale: "zh-CN"
            )
        )
        let started = expectation(description: "First translation started")
        let consumer = Task {
            for try await event in firstEvents {
                if event == .started {
                    started.fulfill()
                }
            }
        }
        await fulfillment(of: [started], timeout: 3)
        consumer.cancel()
        _ = await consumer.result

        let secondEvents = try await core.translate(
            CoreTranslationRequest(
                endpoint: provider.endpoint,
                modelIdentifier: "fake-translator",
                sourceText: "Hello again",
                targetLocale: "zh-CN"
            )
        )
        var output = ""
        var completed = 0
        for try await event in secondEvents {
            switch event {
            case let .textDelta(text):
                output.append(text)
            case .completed:
                completed += 1
            case .cancelled, .failed:
                XCTFail("Expected the immediate retry to complete.")
            case .started:
                break
            }
        }
        XCTAssertEqual(output, "你好，LinguaMesh！")
        XCTAssertEqual(completed, 1)
        try await core.shutdown()
    }
}

// 测试进程只在所属测试方法中按顺序启动和停止。
private final class FakeProviderProcess: @unchecked Sendable {
    let endpoint: String
    private let process: Process

    private init(endpoint: String, process: Process) {
        self.endpoint = endpoint
        self.process = process
    }

    static func start() throws -> FakeProviderProcess {
        guard let script = Bundle.module.url(
            forResource: "fake_provider",
            withExtension: "py",
            subdirectory: "Fixtures"
        ) else {
            throw FakeProviderError.fixtureUnavailable
        }
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", script.path]
        process.standardOutput = output
        process.standardError = errors
        try process.run()

        var line = Data()
        while line.count < 128, !line.contains(0x0a) {
            guard let byte = try output.fileHandleForReading.read(upToCount: 1),
                  !byte.isEmpty
            else {
                process.terminate()
                throw FakeProviderError.startupFailed
            }
            line.append(byte)
        }
        guard let value = String(data: line, encoding: .utf8),
              value.hasPrefix("PORT="),
              let port = UInt16(value.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            process.terminate()
            throw FakeProviderError.startupFailed
        }
        return FakeProviderProcess(
            endpoint: "http://127.0.0.1:\(port)/v1/",
            process: process
        )
    }

    func stop() {
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
    }
}

private enum FakeProviderError: Error {
    case fixtureUnavailable
    case startupFailed
}
