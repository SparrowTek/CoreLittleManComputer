import Foundation
import Testing
@testable import CoreLittleManComputer

/// Checks that every `.lmc` file in `Docs/examples` assembles and produces
/// the outputs its header comment documents.
@Suite("Example files")
struct ExampleFileTests {
    private static let examplesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Docs/examples")

    private static var exampleFiles: [URL] {
        let contents = try? FileManager.default.contentsOfDirectory(at: examplesDirectory, includingPropertiesForKeys: nil)
        return (contents ?? []).filter { $0.pathExtension == "lmc" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    @Test func examplesArePresent() {
        #expect(Self.exampleFiles.map(\.lastPathComponent) == ["countdown.lmc", "multiply.lmc", "subtract.lmc"])
    }

    @Test(arguments: exampleFiles)
    func exampleProducesItsDocumentedOutputs(file: URL) throws {
        let source = try String(contentsOf: file, encoding: .utf8)
        let header = try #require(source.split(whereSeparator: \.isNewline).first { $0.contains("Inputs:") })
        let inputs = try numbers(in: header, after: "Inputs:", before: "Outputs:").map { try #require(Word(rawValue: $0)) }
        let outputs = try numbers(in: header, after: "Outputs:", before: nil).map { try #require(SignedWord(rawValue: $0)) }

        var machine = try Machine(program: Assembler().assemble(source), inbox: inputs)
        #expect(machine.run() == .halted)
        #expect(machine.outbox == outputs)
    }

    private func numbers(in line: Substring, after start: String, before end: String?) throws -> [Int] {
        let afterStart = try #require(line.range(of: start)).upperBound
        let stop = end.flatMap { line.range(of: $0)?.lowerBound } ?? line.endIndex
        return line[afterStart..<stop]
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
}
