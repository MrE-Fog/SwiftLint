import SwiftLintFramework
import XCTest

class MultilineArgumentsRuleTests: XCTestCase {

    func testMultilineArgumentsWithDefaultConfiguration() {
        verifyRule(MultilineArgumentsRule.description)
    }

    func testMultilineArgumentsWithWithNextLine() {
        let nonTriggeringExamples = [
            "foo()",
            "foo(0)",
            "foo(1, bar: baz) { }",
            "foo(2, bar: baz) {\n}",
            "foo(\n" +
            "    3,\n" +
            "    bar: baz) { }",
            "foo(\n" +
            "    4, bar: baz) { }"
        ]

        let triggeringExamples = [
            "foo(β1,\n" +
            "    bar: baz) { }"
        ]

        let description = MultilineArgumentsRule.description
            .with(triggeringExamples: triggeringExamples)
            .with(nonTriggeringExamples: nonTriggeringExamples)

        verifyRule(description, ruleConfiguration: ["first_argument_location": "next_line"])
    }

    func testMultilineArgumentsWithWithSameLine() {
        let nonTriggeringExamples = [
            "foo()",
            "foo(0)",
            "foo(1, bar: 1) { }",
            "foo(2, bar: 2) {\n" +
            "    bar()\n" +
            "}",
            "foo(3,\n" +
            "    bar: 3) { }"
        ]

        let triggeringExamples = [
            "foo(\n" +
            "    β1, βbar: baz) { }",
            "foo(\n" +
            "    β2,\n" +
            "    bar: baz) { }"
        ]

        let description = MultilineArgumentsRule.description
            .with(triggeringExamples: triggeringExamples)
            .with(nonTriggeringExamples: nonTriggeringExamples)

        verifyRule(description, ruleConfiguration: ["first_argument_location": "same_line"])
    }
}
