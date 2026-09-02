/// An assembled program: the initial contents of memory together with the
/// listing information needed to show it as assembly again.
///
/// ``memory`` is what gets loaded into a ``Machine``. ``lines`` describe the
/// mailboxes the assembler filled, in address order, with their labels and
/// source line numbers so front-ends can map between memory and source.
public struct Program: Hashable, Sendable, Codable {
    /// One mailbox filled by the assembler.
    public struct Line: Hashable, Sendable, Codable {
        /// Whether the mailbox came from an instruction or a `DAT` directive.
        public enum Kind: String, Hashable, Sendable, Codable {
            case instruction
            case data
        }

        /// The mailbox this line occupies.
        public var address: MailboxAddress

        /// Whether the mailbox holds an instruction or data.
        public var kind: Kind

        /// The label defined on this line, spelled as the author wrote it.
        public var label: String?

        /// The one-based line number in the assembly source, when known.
        public var sourceLine: Int?

        public init(address: MailboxAddress, kind: Kind, label: String? = nil, sourceLine: Int? = nil) {
            self.address = address
            self.kind = kind
            self.label = label
            self.sourceLine = sourceLine
        }
    }

    /// A program whose memory is entirely `000`.
    public static let empty = Program(memory: .empty)

    /// The initial memory image.
    public var memory: Memory

    /// The mailboxes the assembler filled, in ascending address order.
    public var lines: [Line]

    /// Creates a program from a memory image and optional listing information.
    public init(memory: Memory, lines: [Line] = []) {
        self.memory = memory
        self.lines = lines
    }

    /// Creates a program from raw machine words, or returns `nil` when more
    /// than 100 are supplied.
    public init?(words: [Word]) {
        guard let memory = Memory(words: words) else { return nil }
        self.init(memory: memory)
    }

    /// The number of mailboxes the assembler filled.
    public var length: Int {
        lines.count
    }

    /// Every label with the address it names, spelled as written in the source.
    public var labels: [String: MailboxAddress] {
        var labels: [String: MailboxAddress] = [:]
        for line in lines {
            if let label = line.label {
                labels[label] = line.address
            }
        }
        return labels
    }

    /// The listing entry for `address`, if the assembler filled it.
    public func line(at address: MailboxAddress) -> Line? {
        lines.first { $0.address == address }
    }

    /// The label defined at `address`, if any.
    public func label(at address: MailboxAddress) -> String? {
        line(at: address)?.label
    }

    /// The address a label names, matched without regard to case.
    public func address(ofLabel name: String) -> MailboxAddress? {
        let wanted = name.uppercased()
        return lines.first { $0.label?.uppercased() == wanted }?.address
    }

    /// The source line that produced the word at `address`, if known.
    public func sourceLine(at address: MailboxAddress) -> Int? {
        line(at: address)?.sourceLine
    }

    /// The address whose word came from source line `sourceLine`, if any.
    public func address(ofSourceLine sourceLine: Int) -> MailboxAddress? {
        lines.first { $0.sourceLine == sourceLine }?.address
    }

    /// The instruction at `address`, or `nil` when that word is not an instruction.
    public func instruction(at address: MailboxAddress) -> Instruction? {
        Instruction(word: memory[address])
    }
}
