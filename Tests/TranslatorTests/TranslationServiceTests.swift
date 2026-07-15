import Foundation
import XCTest
@testable import Translator

final class TranslationServiceTests: XCTestCase {
    func testBuildsAutoPrompt() {
        let prompt = TranslationService.makePrompt(for: "你好", mode: .auto)

        XCTAssertTrue(prompt.contains("Detect the language"))
        XCTAssertTrue(prompt.contains("Return only the translation result."))
        XCTAssertTrue(prompt.contains("你好"))
    }

    func testBuildsZhToEnPrompt() {
        let prompt = TranslationService.makePrompt(for: "你好", mode: .zhToEn)

        XCTAssertTrue(prompt.contains("Chinese text into natural English"))
    }

    func testExtractsOutputTextField() throws {
        let data = #"{"output_text":"Hello world"}"#.data(using: .utf8)!

        let result = try TranslationService.extractTranslation(from: data)

        XCTAssertEqual(result, "Hello world")
    }

    func testExtractsNestedContentText() throws {
        let data = #"""
        {
          "output": [
            {
              "content": [
                {
                  "type": "output_text",
                  "text": "你好世界"
                }
              ]
            }
          ]
        }
        """#.data(using: .utf8)!

        let result = try TranslationService.extractTranslation(from: data)

        XCTAssertEqual(result, "你好世界")
    }

    func testStripsThinkingProcess() {
        XCTAssertEqual(
            TranslationService.stripThinkingProcess("<think>I am thinking\nabout this</think>Hello world"),
            "Hello world"
        )
        XCTAssertEqual(
            TranslationService.stripThinkingProcess("<thought>Analyzing...</thought>Hello!"),
            "Hello!"
        )
        XCTAssertEqual(
            TranslationService.stripThinkingProcess("<think>Oops incomplete tag"),
            ""
        )
        XCTAssertEqual(
            TranslationService.stripThinkingProcess("No thinking tags at all"),
            "No thinking tags at all"
        )
    }

    func testExtractsOpenAIChatCompletions() throws {
        let data = #"""
        {
          "choices": [
            {
              "message": {
                "role": "assistant",
                "content": "<think>some thought</think>Actual Translation result"
              }
            }
          ]
        }
        """#.data(using: .utf8)!

        let result = try TranslationService.extractTranslation(from: data)
        XCTAssertEqual(result, "Actual Translation result")
    }

    func testExtractsTranslationFromLMStudioReasoningResponse() throws {
        let jsonString = #"""
        {
          "output": [
            {
              "type": "reasoning",
              "content": [
                {
                  "type": "reasoning_text",
                  "text": "Thinking Process:\n1. Translate..."
                }
              ]
            },
            {
              "type": "message",
              "content": [
                {
                  "type": "output_text",
                  "text": "Will you walk this long road with me?"
                }
              ]
            }
          ]
        }
        """#
        let data = jsonString.data(using: .utf8)!
        let result = try TranslationService.extractTranslation(from: data)
        XCTAssertEqual(result, "Will you walk this long road with me?")
    }

    func testThrowsForInvalidPayload() {
        let data = #"{"status":"ok"}"#.data(using: .utf8)!

        XCTAssertThrowsError(try TranslationService.extractTranslation(from: data)) { error in
            XCTAssertEqual(error as? TranslationServiceError, .emptyResult)
        }
    }
}

@MainActor
final class TranslatorViewModelTests: XCTestCase {
    func testIgnoresEmptyInput() async {
        let service = MockTranslationService()
        let viewModel = TranslatorViewModel(service: service)
        viewModel.inputText = " \n "

        await viewModel.performTranslation()

        XCTAssertEqual(service.callCount, 0)
        XCTAssertTrue(viewModel.outputText.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testMapsServiceErrorToUiMessage() async {
        let service = MockTranslationService(result: .failure(.serverError(500)))
        let viewModel = TranslatorViewModel(service: service)
        viewModel.inputText = "hello"

        await viewModel.performTranslation()

        XCTAssertTrue(viewModel.outputText.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "LM Studio returned HTTP 500.")
    }
}

private final class MockTranslationService: @unchecked Sendable, TranslationServiceProtocol {
    private(set) var callCount = 0
    private let result: Result<String, TranslationServiceError>

    init(result: Result<String, TranslationServiceError> = .success("translated")) {
        self.result = result
    }

    func translate(text: String, mode: TranslationMode) async throws -> String {
        callCount += 1
        return try result.get()
    }
}
