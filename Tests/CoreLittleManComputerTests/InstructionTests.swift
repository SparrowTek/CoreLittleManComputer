#if canImport(Testing)
import Testing
@testable import CoreLittleManComputer

@Suite("Instructions")
struct InstructionTests {

    @Test func encoding_and_decoding_round_trip() throws {
        let address = MailboxAddress(23)
        let instruction = try Instruction(opcode: .add, operand: .address(address))
        let encoded = try InstructionWord.encode(instruction)
        #expect(encoded.rawValue == 123)

        let decoded = try InstructionWord(encoded).decode()
        guard case let .instruction(decodedInstruction) = decoded else {
            Issue.record("expected instruction")
            return
        }
        #expect(decodedInstruction == instruction)
    }

    @Test func decoding_of_literals() throws {
        let literalWord = Word(signedValue: -1)
        let decoded = try InstructionWord(literalWord).decode()
        guard case let .data(word) = decoded else {
            Issue.record("expected data literal")
            return
        }
        #expect(word == literalWord)

        let dataInstruction = try Instruction(opcode: .data, operand: .literal(-1))
        let encoded = try InstructionWord.encode(dataInstruction)
        #expect(encoded.rawValue == 999)
    }

    @Test func all_opcodes_encode_and_decode() throws {
        let addressOpcodes: [Opcode] = [.add, .subtract, .store, .load, .branch, .branchIfZero, .branchIfPositive]
        for opcode in addressOpcodes {
            let instruction = try Instruction(opcode: opcode, operand: .address(MailboxAddress(50)))
            let word = try InstructionWord.encode(instruction)
            let decoded = try InstructionWord(word).decode()
            guard case let .instruction(result) = decoded else {
                Issue.record("Expected instruction for \(opcode)")
                continue
            }
            #expect(result == instruction)
        }
    }

    @Test func noOperand_opcodes_reject_operands() {
        #expect(throws: InstructionError.self) {
            try Instruction(opcode: .halt, operand: .address(MailboxAddress(0)))
        }
        #expect(throws: InstructionError.self) {
            try Instruction(opcode: .input, operand: .address(MailboxAddress(0)))
        }
    }

    @Test func address_opcodes_reject_missing_operand() {
        #expect(throws: InstructionError.self) {
            try Instruction(opcode: .add, operand: .none)
        }
    }

    @Test func instruction_description() throws {
        let add = try Instruction(opcode: .add, operand: .address(MailboxAddress(5)))
        #expect(add.description == "ADD 5")

        let halt = try Instruction(opcode: .halt)
        #expect(halt.description == "HLT")

        let dat = try Instruction(opcode: .data, operand: .literal(42))
        #expect(dat.description == "DAT 42")
    }

    @Test func opcode_4xx_decoded_as_data() throws {
        let word = Word(400)
        let decoded = try InstructionWord(word).decode()
        guard case .data = decoded else {
            Issue.record("Expected 4xx to decode as data")
            return
        }
    }
}
#endif
