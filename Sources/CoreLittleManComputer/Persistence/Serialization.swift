import Foundation

public enum ProgramSerializationError: Error, Sendable, Equatable, CustomStringConvertible {
    case decodingFailure(String)
    case encodingFailure(String)
    case snapshot(SnapshotError)

    public var description: String {
        switch self {
        case .decodingFailure(let message):
            return "Decoding failure: \(message)"
        case .encodingFailure(let message):
            return "Encoding failure: \(message)"
        case .snapshot(let error):
            return "Snapshot error: \(error)"
        }
    }
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
            throw ProgramSerializationError.encodingFailure(String(describing: error))
        }
    }

    public func importJSON(_ data: Data) throws -> Program {
        do {
            let snapshot = try decoder.decode(ProgramSnapshot.self, from: data)
            guard snapshot.version <= ProgramSnapshot.currentVersion else {
                throw ProgramSerializationError.snapshot(.versionMismatch(snapshot.version))
            }
            return try Program(snapshot: snapshot)
        } catch let error as SnapshotError {
            throw ProgramSerializationError.snapshot(error)
        } catch {
            throw ProgramSerializationError.decodingFailure(String(describing: error))
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
            guard snapshot.version <= ProgramStateSnapshot.currentVersion else {
                throw ProgramSerializationError.snapshot(.versionMismatch(snapshot.version))
            }
            return try ProgramState(snapshot: snapshot)
        } catch let error as SnapshotError {
            throw ProgramSerializationError.snapshot(error)
        } catch {
            throw ProgramSerializationError.decodingFailure(String(describing: error))
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
