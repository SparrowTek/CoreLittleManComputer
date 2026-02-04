#if canImport(Testing)
import Testing
@testable import CoreLittleManComputer

@Suite("Core Value Types")
struct CoreTypeTests {

    // MARK: - Word

    @Suite("Word")
    struct WordTests {
        @Test func signedConversionRoundTrip() {
            let negativeOne = Word(signedValue: -1)
            #expect(negativeOne.rawValue == 999)
            #expect(negativeOne.signedValue == -1)

            let positive = Word(123)
            #expect(positive.signedValue == 123)
            #expect(positive.zeroPaddedString == "123")

            let padded = Word(7)
            #expect(padded.zeroPaddedString == "007")
        }

        @Test func failable_init_accepts_valid() {
            #expect(Word(exactly: 0) != nil)
            #expect(Word(exactly: 999) != nil)
            #expect(Word(exactly: 500) != nil)
        }

        @Test func failable_init_rejects_invalid() {
            #expect(Word(exactly: -1) == nil)
            #expect(Word(exactly: 1000) == nil)
            #expect(Word(exactly: Int.max) == nil)
        }

        @Test func signedFailable_init_accepts_valid() {
            #expect(Word(signedExactly: -500) != nil)
            #expect(Word(signedExactly: 499) != nil)
            #expect(Word(signedExactly: 0) != nil)
        }

        @Test func signedFailable_init_rejects_invalid() {
            #expect(Word(signedExactly: -501) == nil)
            #expect(Word(signedExactly: 500) == nil)
        }

        @Test func highDigit_and_lowValue() {
            let word = Word(123)
            #expect(word.highDigit == 1)
            #expect(word.lowValue == 23)

            let zero = Word.zero
            #expect(zero.highDigit == 0)
            #expect(zero.lowValue == 0)

            let max = Word(999)
            #expect(max.highDigit == 9)
            #expect(max.lowValue == 99)
        }

        @Test func description_uses_zero_padding() {
            #expect(Word(7).description == "007")
            #expect(Word(42).description == "042")
            #expect(Word(999).description == "999")
        }
    }

    // MARK: - MailboxAddress

    @Suite("MailboxAddress")
    struct MailboxAddressTests {
        @Test func failable_init_accepts_valid() {
            #expect(MailboxAddress(exactly: 0) != nil)
            #expect(MailboxAddress(exactly: 99) != nil)
        }

        @Test func failable_init_rejects_invalid() {
            #expect(MailboxAddress(exactly: -1) == nil)
            #expect(MailboxAddress(exactly: 100) == nil)
        }

        @Test func comparable() {
            #expect(MailboxAddress(0) < MailboxAddress(1))
            #expect(MailboxAddress(99) > MailboxAddress(0))
        }

        @Test func advanced() {
            let addr = MailboxAddress(5)
            #expect(addr.advanced(by: 3) == MailboxAddress(8))
        }

        @Test func description() {
            #expect(MailboxAddress(42).description == "42")
        }
    }

    // MARK: - Accumulator

    @Suite("Accumulator")
    struct AccumulatorTests {
        @Test func failable_init_accepts_valid() {
            #expect(Accumulator(exactly: -500) != nil)
            #expect(Accumulator(exactly: 499) != nil)
            #expect(Accumulator(exactly: 0) != nil)
        }

        @Test func failable_init_rejects_invalid() {
            #expect(Accumulator(exactly: -501) == nil)
            #expect(Accumulator(exactly: 500) == nil)
        }

        @Test func description() {
            #expect(Accumulator(42).description == "42")
            #expect(Accumulator(-1).description == "-1")
        }
    }

    // MARK: - NumericPolicy

    @Suite("NumericPolicy")
    struct NumericPolicyTests {
        @Test func trapOnOverflow_throws() {
            #expect(throws: NumericError.overflow(value: 600)) {
                try NumericPolicy.trapOnOverflow.accumulator(from: 600)
            }
        }

        @Test func trapOnOverflow_throws_for_negative() {
            #expect(throws: NumericError.overflow(value: -501)) {
                try NumericPolicy.trapOnOverflow.accumulator(from: -501)
            }
        }

        @Test func wrapModulo_wraps_positive() throws {
            let accumulator = try NumericPolicy.wrapModulo.accumulator(from: 600)
            #expect(accumulator.value == -400)
        }

        @Test func wrapModulo_wraps_negative() throws {
            let word = try NumericPolicy.wrapModulo.word(fromSigned: -1)
            #expect(word.rawValue == 999)
        }

        @Test func wrapModulo_boundary_values() throws {
            let upper = try NumericPolicy.wrapModulo.accumulator(from: 500)
            #expect(upper.value == -500)

            let lower = try NumericPolicy.wrapModulo.accumulator(from: -501)
            #expect(lower.value == 499)
        }
    }
}
#endif
