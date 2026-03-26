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
