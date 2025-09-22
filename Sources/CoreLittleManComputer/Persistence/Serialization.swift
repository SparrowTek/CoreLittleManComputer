import Foundation

public enum ProgramSerializationError: Error, Sendable {
    case decodingFailure(Error)
    case encodingFailure(Error)
    case snapshot(SnapshotError)
}

public struct ProgramSerializer: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(prettyPrinted: Bool = false) {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        encoder.outputFormatting.insert(.sortedKeys)
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func exportJSON(_ program: Program) throws -> Data {
        let snapshot = program.snapshot()
        do {
            return try encoder.encode(snapshot)
        } catch {
            throw ProgramSerializationError.encodingFailure(error)
        }
    }

    public func importJSON(_ data: Data) throws -> Program {
        do {
            let snapshot = try decoder.decode(ProgramSnapshot.self, from: data)
            return try Program(snapshot: snapshot)
        } catch let error as SnapshotError {
            throw ProgramSerializationError.snapshot(error)
        } catch {
            throw ProgramSerializationError.decodingFailure(error)
        }
    }
}

public struct ProgramStateSerializer: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(prettyPrinted: Bool = false) {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        encoder.outputFormatting.insert(.sortedKeys)
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func exportJSON(_ state: ProgramState) throws -> Data {
        let snapshot = state.snapshot()
        return try encoder.encode(snapshot)
    }

    public func importJSON(_ data: Data) throws -> ProgramState {
        do {
            let snapshot = try decoder.decode(ProgramStateSnapshot.self, from: data)
            return try ProgramState(snapshot: snapshot)
        } catch let error as SnapshotError {
            throw ProgramSerializationError.snapshot(error)
        } catch {
            throw ProgramSerializationError.decodingFailure(error)
        }
    }
}

public struct ProgramTextCodec: Sendable {
    private let assembler: Assembler

    public init(numericPolicy: NumericPolicy = .trapOnOverflow) {
        self.assembler = Assembler(numericPolicy: numericPolicy)
    }

    public func assemble(_ text: String) throws -> Program {
        try assembler.assemble(text)
    }

    public func disassemble(_ program: Program) -> String {
        assembler.disassemble(program)
    }
}
