/// Renders a ``Program`` or a ``Memory`` image as assembly source.
///
/// The output reassembles to the same memory image. Mailboxes the assembler
/// marked as data, and words that are not the canonical encoding of an
/// instruction, are written as `DAT`. Operands that point at a labelled
/// mailbox use the label.
public struct Disassembler: Sendable {
    public init() {}

    /// Renders every mailbox the assembler filled, one statement per line.
    ///
    /// A program without listing information is rendered up to its last
    /// non-zero mailbox, treating every word as an instruction when possible.
    public func disassemble(_ program: Program) -> String {
        let lines = program.lines.isEmpty ? rawLines(for: program.memory) : program.lines

        var labels: [MailboxAddress: String] = [:]
        for line in lines {
            if let label = line.label, labels[line.address] == nil {
                labels[line.address] = label
            }
        }
        let labelWidth = labels.values.map(\.count).max() ?? 0

        return lines.map { line in
            let word = program.memory[line.address]
            let statement: String
            switch line.kind {
            case .instruction:
                if let instruction = Instruction(word: word), instruction.word == word {
                    statement = render(instruction, labels: labels)
                } else {
                    statement = "DAT \(word.rawValue)"
                }
            case .data:
                statement = "DAT \(word.rawValue)"
            }

            guard labelWidth > 0 else { return statement }
            let label = labels[line.address] ?? ""
            let padding = String(repeating: " ", count: labelWidth - label.count + 1)
            return label + padding + statement
        }
        .joined(separator: "\n")
    }

    /// Renders `memory` up to its last non-zero mailbox.
    public func disassemble(_ memory: Memory) -> String {
        disassemble(Program(memory: memory))
    }

    private func rawLines(for memory: Memory) -> [Program.Line] {
        guard let last = memory.lastOccupiedAddress else { return [] }
        return MailboxAddress.allCases.prefix(last.rawValue + 1).map {
            Program.Line(address: $0, kind: .instruction)
        }
    }

    private func render(_ instruction: Instruction, labels: [MailboxAddress: String]) -> String {
        guard let address = instruction.address else {
            return instruction.opcode.mnemonic
        }
        return "\(instruction.opcode.mnemonic) \(labels[address] ?? address.description)"
    }
}
