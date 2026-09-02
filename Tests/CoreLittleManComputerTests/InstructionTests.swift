import Testing
@testable import CoreLittleManComputer

@Suite("Opcode")
struct OpcodeTests {
    @Test func coversTheTenOperations() {
        #expect(Opcode.allCases.count == 10)
        #expect(Opcode.allCases.map(\.mnemonic) == ["ADD", "SUB", "STA", "LDA", "BRA", "BRZ", "BRP", "INP", "OUT", "HLT"])
    }

    @Test func knowsWhichOperationsAddressAMailbox() {
        let addressed = Opcode.allCases.filter(\.takesAddress)
        #expect(addressed == [.add, .subtract, .store, .load, .branchAlways, .branchIfZero, .branchIfPositive])
    }

    @Test func encodesBaseWords() {
        #expect(Opcode.add.baseWord == 100)
        #expect(Opcode.subtract.baseWord == 200)
        #expect(Opcode.store.baseWord == 300)
        #expect(Opcode.load.baseWord == 500)
        #expect(Opcode.branchAlways.baseWord == 600)
        #expect(Opcode.branchIfZero.baseWord == 700)
        #expect(Opcode.branchIfPositive.baseWord == 800)
        #expect(Opcode.input.baseWord == 901)
        #expect(Opcode.output.baseWord == 902)
        #expect(Opcode.halt.baseWord == .zero)
    }

    @Test func offersTheWikipediaAliases() {
        #expect(Opcode.store.aliases == ["STO"])
        #expect(Opcode.halt.aliases == ["COB"])
        #expect(Opcode.add.aliases.isEmpty)
    }

    @Test func summarisesEveryOperation() {
        for opcode in Opcode.allCases {
            #expect(!opcode.summary.isEmpty)
        }
    }
}

@Suite("Instruction")
struct InstructionTests {
    @Test func decodesCanonicalWords() {
        #expect(Instruction(word: 105) == .add(5))
        #expect(Instruction(word: 299) == .subtract(99))
        #expect(Instruction(word: 300) == .store(0))
        #expect(Instruction(word: 542) == .load(42))
        #expect(Instruction(word: 600) == .branchAlways(0))
        #expect(Instruction(word: 715) == .branchIfZero(15))
        #expect(Instruction(word: 899) == .branchIfPositive(99))
        #expect(Instruction(word: 901) == .input)
        #expect(Instruction(word: 902) == .output)
        #expect(Instruction(word: .zero) == .halt)
    }

    @Test func anyWordBelowOneHundredHalts() {
        for value in 0..<100 {
            #expect(Instruction(word: Word(wrapping: value)) == .halt)
        }
    }

    @Test func fourHundredsAreNotInstructions() {
        for value in 400...499 {
            #expect(Instruction(word: Word(wrapping: value)) == nil)
        }
    }

    @Test func onlyInputAndOutputExistInTheNineHundreds() {
        for value in 900...999 {
            let instruction = Instruction(word: Word(wrapping: value))
            switch value {
            case 901: #expect(instruction == .input)
            case 902: #expect(instruction == .output)
            default: #expect(instruction == nil)
            }
        }
    }

    @Test func decodesExactlyEightHundredAndTwoWords() {
        let decodable = Word.range.filter { Instruction(word: Word(wrapping: $0)) != nil }
        #expect(decodable.count == 802)
    }

    @Test func canonicalWordsRoundTrip() {
        for value in Word.range {
            let word = Word(wrapping: value)
            guard let instruction = Instruction(word: word) else { continue }
            if word.hundredsDigit == 0 {
                #expect(instruction.word == .zero)
            } else {
                #expect(instruction.word == word)
            }
        }
    }

    @Test func pairsOpcodesWithAddresses() {
        #expect(Instruction(opcode: .add, address: 7) == .add(7))
        #expect(Instruction(opcode: .halt, address: nil) == .halt)
        #expect(Instruction(opcode: .add, address: nil) == nil)
        #expect(Instruction(opcode: .halt, address: 7) == nil)
        for opcode in Opcode.allCases {
            let address: MailboxAddress? = opcode.takesAddress ? 12 : nil
            let instruction = Instruction(opcode: opcode, address: address)
            #expect(instruction?.opcode == opcode)
            #expect(instruction?.address == address)
        }
    }

    @Test func identifiesBranches() {
        #expect(Instruction.branchAlways(0).isBranch)
        #expect(Instruction.branchIfZero(0).isBranch)
        #expect(Instruction.branchIfPositive(0).isBranch)
        #expect(!Instruction.add(0).isBranch)
        #expect(!Instruction.halt.isBranch)
    }

    @Test func describesItselfAsAssembly() {
        #expect(Instruction.add(5).description == "ADD 05")
        #expect(Instruction.branchIfPositive(99).description == "BRP 99")
        #expect(Instruction.input.description == "INP")
        #expect(Instruction.halt.description == "HLT")
    }
}
