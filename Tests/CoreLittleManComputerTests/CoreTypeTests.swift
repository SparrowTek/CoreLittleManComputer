import Testing
@testable import CoreLittleManComputer

@Suite("Word")
struct WordTests {
    @Test func acceptsEveryValueInRange() {
        for value in Word.range {
            #expect(Word(rawValue: value)?.rawValue == value)
        }
    }

    @Test(arguments: [-1, 1_000, Int.min, Int.max])
    func rejectsValuesOutsideRange(value: Int) {
        #expect(Word(rawValue: value) == nil)
    }

    @Test(arguments: [
        (0, 0), (999, 999), (1_000, 0), (1_234, 234), (-1, 999), (-1_000, 0), (-1_001, 999),
        (Int.max, 807), (Int.min, 192),
    ])
    func wrapsToLowThreeDigits(pair: (value: Int, expected: Int)) {
        #expect(Word(wrapping: pair.value).rawValue == pair.expected)
    }

    @Test func splitsIntoOpcodeDigitAndAddressField() {
        #expect(Word(123).hundredsDigit == 1)
        #expect(Word(123).addressField == 23)
        #expect(Word.zero.hundredsDigit == 0)
        #expect(Word.zero.addressField == 0)
        #expect(Word(999).hundredsDigit == 9)
        #expect(Word(999).addressField == 99)
        #expect(Word(905).addressField == 5)
    }

    @Test func describesItselfWithThreeDigits() {
        #expect(Word.zero.description == "000")
        #expect(Word(7).description == "007")
        #expect(Word(42).description == "042")
        #expect(Word(999).description == "999")
    }

    @Test func parsesDecimalText() {
        #expect(Word("42") == 42)
        #expect(Word("042") == 42)
        #expect(Word("000") == .zero)
        #expect(Word("1000") == nil)
        #expect(Word("-1") == nil)
        #expect(Word("abc") == nil)
        #expect(Word("") == nil)
    }

    @Test func comparesByValue() {
        #expect(Word(1) < Word(2))
        #expect(Word(999) > Word.zero)
        #expect([Word(5), 1, 3].sorted() == [1, 3, 5])
    }
}

@Suite("SignedWord")
struct SignedWordTests {
    @Test func acceptsEveryValueInRange() {
        for value in SignedWord.range {
            #expect(SignedWord(rawValue: value)?.rawValue == value)
        }
    }

    @Test(arguments: [-1_000, 1_000, Int.min, Int.max])
    func rejectsValuesOutsideRange(value: Int) {
        #expect(SignedWord(rawValue: value) == nil)
    }

    @Test func convertsFromWordWithoutLoss() {
        for value in Word.range {
            #expect(SignedWord(Word(wrapping: value)).rawValue == value)
        }
    }

    @Test(arguments: [
        (0, 0), (999, 999), (-999, -999), (1_000, 0), (-1_000, 0), (1_200, 200), (-1_200, -200),
        (1_998, 998), (-1_998, -998), (Int.min, -808),
    ])
    func wrapsKeepingSignAndLowThreeDigits(pair: (value: Int, expected: Int)) {
        #expect(SignedWord(wrapping: pair.value).rawValue == pair.expected)
    }

    @Test func storesNegativeValuesInTensComplement() {
        #expect(SignedWord.zero.storedWord == .zero)
        #expect(SignedWord(42).storedWord == 42)
        #expect(SignedWord(999).storedWord == 999)
        #expect(SignedWord(-1).storedWord == 999)
        #expect(SignedWord(-999).storedWord == 1)
        #expect(SignedWord(-500).storedWord == 500)
    }

    @Test func reportsSign() {
        #expect(SignedWord(-1).isNegative)
        #expect(!SignedWord.zero.isNegative)
        #expect(!SignedWord(1).isNegative)
        #expect(SignedWord.zero.isZero)
        #expect(!SignedWord(-1).isZero)
    }

    @Test func describesAndParsesPlainDecimal() {
        #expect(SignedWord(-3).description == "-3")
        #expect(SignedWord(42).description == "42")
        #expect(SignedWord.zero.description == "0")
        #expect(SignedWord("-3") == -3)
        #expect(SignedWord("042") == 42)
        #expect(SignedWord("1000") == nil)
        #expect(SignedWord("x") == nil)
    }

    @Test func comparesByValue() {
        #expect(SignedWord(-1) < .zero)
        #expect(SignedWord(999) > SignedWord(-999))
    }
}

@Suite("MailboxAddress")
struct MailboxAddressTests {
    @Test func acceptsEveryValueInRange() {
        for value in MailboxAddress.range {
            #expect(MailboxAddress(rawValue: value)?.rawValue == value)
        }
    }

    @Test(arguments: [-1, 100, Int.min, Int.max])
    func rejectsValuesOutsideRange(value: Int) {
        #expect(MailboxAddress(rawValue: value) == nil)
    }

    @Test func wrapsToLowTwoDigits() {
        #expect(MailboxAddress(wrapping: 100) == 0)
        #expect(MailboxAddress(wrapping: 123) == 23)
        #expect(MailboxAddress(wrapping: -1) == 99)
    }

    @Test func successorWrapsLikeTheProgramCounter() {
        #expect(MailboxAddress(5).successor == 6)
        #expect(MailboxAddress(99).successor == 0)
    }

    @Test func enumeratesEveryMailboxInOrder() {
        #expect(MailboxAddress.allCases.count == MailboxAddress.count)
        #expect(MailboxAddress.allCases.map(\.rawValue) == Array(MailboxAddress.range))
    }

    @Test func describesAndParsesTwoDigits() {
        #expect(MailboxAddress(7).description == "07")
        #expect(MailboxAddress(42).description == "42")
        #expect(MailboxAddress.zero.description == "00")
        #expect(MailboxAddress("7") == 7)
        #expect(MailboxAddress("07") == 7)
        #expect(MailboxAddress("100") == nil)
        #expect(MailboxAddress("x") == nil)
    }

    @Test func comparesByValue() {
        #expect(MailboxAddress.zero < MailboxAddress(1))
        #expect(MailboxAddress(99) > MailboxAddress(50))
    }
}

@Suite("Memory")
struct MemoryTests {
    @Test func startsBlank() {
        let memory = Memory()
        #expect(memory.words.count == MailboxAddress.count)
        #expect(memory.words.allSatisfy { $0 == .zero })
        #expect(memory.lastOccupiedAddress == nil)
        #expect(memory == .empty)
    }

    @Test func padsShortImagesWithZeros() throws {
        let memory = try #require(Memory(words: [901, 902, 0]))
        #expect(memory.words.count == MailboxAddress.count)
        #expect(memory[0] == 901)
        #expect(memory[1] == 902)
        #expect(memory[2] == .zero)
        #expect(memory[99] == .zero)
        #expect(memory.lastOccupiedAddress == 1)
    }

    @Test func acceptsExactlyOneHundredWords() {
        let full = Memory(words: Array(repeating: Word(7), count: 100))
        #expect(full?.lastOccupiedAddress == 99)
        #expect(Memory(words: Array(repeating: Word(7), count: 101)) == nil)
    }

    @Test func readsAndWritesByAddress() {
        var memory = Memory()
        memory[42] = 123
        #expect(memory[42] == 123)
        #expect(memory.words[42] == 123)
        #expect(memory.lastOccupiedAddress == 42)
        memory[42] = .zero
        #expect(memory.lastOccupiedAddress == nil)
    }
}
