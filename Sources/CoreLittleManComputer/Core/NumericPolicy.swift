public enum NumericPolicy: Sendable {
    case trapOnOverflow
    case wrapModulo

    public func accumulator(from value: Int) throws -> Accumulator {
        let normalized = try normalizeSigned(value)
        return Accumulator(normalized)
    }

    public func word(fromSigned value: Int) throws -> Word {
        let normalized = try normalizeSigned(value)
        return Word(signedValue: normalized)
    }

    public func word(fromUnsigned value: Int) throws -> Word {
        let normalized = try normalizeUnsigned(value)
        return Word(normalized)
    }

    private func normalizeSigned(_ value: Int) throws -> Int {
        switch self {
        case .trapOnOverflow:
            guard LMCConstants.signedWordRange.contains(value) else {
                throw NumericError.overflow(value: value)
            }
            return value
        case .wrapModulo:
            let wrapped = wrap(value)
            if wrapped > LMCConstants.signedWordRange.upperBound {
                return wrapped - LMCConstants.decimalBase
            }
            return wrapped
        }
    }

    private func normalizeUnsigned(_ value: Int) throws -> Int {
        switch self {
        case .trapOnOverflow:
            guard LMCConstants.wordRange.contains(value) else {
                throw NumericError.overflow(value: value)
            }
            return value
        case .wrapModulo:
            return wrap(value)
        }
    }

    private func wrap(_ value: Int) -> Int {
        var normalized = value % LMCConstants.decimalBase
        if normalized < 0 { normalized += LMCConstants.decimalBase }
        return normalized
    }
}
