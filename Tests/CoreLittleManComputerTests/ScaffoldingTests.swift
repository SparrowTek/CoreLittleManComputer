#if canImport(Testing)
import Testing
@testable import CoreLittleManComputer

@Test
func wordSignedConversionRoundTrip() {
    let negativeOne = Word(signedValue: -1)
    #expect(negativeOne.rawValue == 999)
    #expect(negativeOne.signedValue == -1)

    let positive = Word(123)
    #expect(positive.signedValue == 123)
}

@Test
func mailboxAddressValidation() {
    _ = MailboxAddress(0)
    _ = MailboxAddress(99)
}
#else
#warning("Swift Testing is unavailable; CoreLittleManComputer tests are stubs until the toolchain provides the Testing module.")
#endif
