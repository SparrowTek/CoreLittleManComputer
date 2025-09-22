import Foundation

public struct TraceFormatter: Sendable {
    public enum Style: Sendable {
        case singleLine
        case multiLine
    }

    public var style: Style
    public var includeHeader: Bool

    public init(style: Style = .singleLine, includeHeader: Bool = true) {
        self.style = style
        self.includeHeader = includeHeader
    }

    public func render(_ trace: [ProgramState.TraceEntry]) -> String {
        guard !trace.isEmpty else { return "" }
        switch style {
        case .singleLine:
            return renderSingleLine(trace)
        case .multiLine:
            return renderMultiLine(trace)
        }
    }

    private func renderSingleLine(_ trace: [ProgramState.TraceEntry]) -> String {
        let rows = trace.map { entry -> String in
            let opcode = entry.instruction?.opcode.metadata.mnemonic ?? "---"
            return "\(entry.cycle)\t\(entry.counter.rawValue)\t\(opcode)\t\(entry.accumulator.value)"
        }
        guard includeHeader else { return rows.joined(separator: "\n") }
        let header = "cycle\tcounter\topcode\taccumulator"
        return ([header] + rows).joined(separator: "\n")
    }

    private func renderMultiLine(_ trace: [ProgramState.TraceEntry]) -> String {
        trace.map { entry in
            var lines: [String] = []
            lines.append("Cycle: \(entry.cycle)")
            lines.append("Counter: \(entry.counter.rawValue)")
            if let instruction = entry.instruction {
                lines.append("Instruction: \(instruction.opcode.metadata.mnemonic)")
            } else {
                lines.append("Instruction: ---")
            }
            lines.append("Accumulator: \(entry.accumulator.value)")
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}

public struct StateSnapshotFormatter: Sendable {
    public func render(_ state: ProgramState) -> String {
        var lines: [String] = []
        lines.append("Counter: \(state.counter.rawValue)")
        lines.append("Accumulator: \(state.accumulator.value)")
        lines.append("Inbox: \(state.inbox)")
        lines.append("Outbox: \(state.outbox)")
        lines.append("Halted: \(state.halted)")
        lines.append("Cycles: \(state.cycles)")
        return lines.joined(separator: "\n")
    }
}
