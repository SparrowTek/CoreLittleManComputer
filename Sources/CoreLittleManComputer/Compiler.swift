import Foundation

public enum CompilationError: Error {
    case invalidAssemblyCode
    case intExpected
    case badOpcode
}

public struct Compiler {
    public func compile(_ code: String) throws -> Program {
        let linesOfCode = createStringArray(from: code, seperatedBy: .newlines)
        let executableCode = try interpretLinesOfCode(linesOfCode)
        return try programFromExecuatableCode(executableCode)
    }
    
    private func programFromExecuatableCode(_ executableCode: [ExecutableCode]) throws -> Program {
        let leadingLabels = trackLabels(for: executableCode)
        let registers = try setRegisters(executableCode, leadingLabels: leadingLabels)
        return Program(registers: registers)
    }
    
    private func trackLabels(for executableCode: [ExecutableCode]) -> [String : Int] {
        var registerCount = 0
        var leadingLabelDictionary = [String : Int]()
        for code in executableCode {
            
            if let leadingLabel = code.leadingLabel {
                leadingLabelDictionary[leadingLabel] = registerCount
            }
            
            registerCount += 1
        }
        
        return leadingLabelDictionary
    }
    
    private func setRegisters(_ executableCode: [ExecutableCode], leadingLabels: [String : Int]) throws -> [Register] {
        var registers = [Register](repeating: 000, count: 100)
        
        for index in 0..<executableCode.count {
            registers[index] = try getRegisterValue(for: executableCode[index], leadingLabels: leadingLabels)
        }
        
        return registers
    }
    
    private func getRegisterValue(for executableCode: ExecutableCode, leadingLabels: [String : Int]) throws -> Int {
        if executableCode.opcode == .data {
            if executableCode.leadingLabel != nil, let value = executableCode.value {
                return value
            } else if executableCode.leadingLabel != nil {
                return 0
            } else if let value = executableCode.value {
                return value
            } else {
                throw CompilationError.invalidAssemblyCode
            }
        }
        
        if executableCode.opcode == .input || executableCode.opcode == .output || executableCode.opcode == .halt {
            return executableCode.opcode.registerValue
        }
        
        let mailbox = try setMailboxWith(trailingLabel: executableCode.trailingLabel, leadingLabel: leadingLabels)
        return executableCode.opcode.registerValue + mailbox
    }
    
    private func setMailboxWith(trailingLabel: String?, leadingLabel: [String : Int]) throws -> Int {
        guard let trailingLabel, let mailBox = leadingLabel[trailingLabel] else { throw CompilationError.invalidAssemblyCode }
        return mailBox
    }
    
    private func createStringArray(from code: String, seperatedBy characterSet: CharacterSet) -> [String] {
        let codeWithoutLeadingAndTrailingWhiteSpace = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return codeWithoutLeadingAndTrailingWhiteSpace.components(separatedBy: characterSet)
    }
    
    private func interpretLinesOfCode(_ linesOfCode: [String]) throws -> [ExecutableCode] {
        var executableCode: [ExecutableCode] = []
        
        for line in linesOfCode {
            let args = createStringArray(from: line, seperatedBy: .whitespaces)
            
            switch args.count {
            case 1: executableCode.append(try interpretLinesOfCodeWith1Arg(args))
            case 2: executableCode.append(try interpretLinesOfCodeWith2Args(args))
            case 3: executableCode.append(try interpretLinesOfCodeWith3Args(args))
            default: throw CompilationError.invalidAssemblyCode
            }
        }
        
        return executableCode
    }
    
    private func testForValidCodeLine(opcode: Opcode, value: Int?, leadingLabel: String?) throws {
        if opcode == .data && value == nil && leadingLabel == nil {
            throw CompilationError.invalidAssemblyCode
        }
    }
    
    private func interpretLinesOfCodeWith1Arg(_ args: [String]) throws -> ExecutableCode {
        guard let opcode = Opcode(rawValue: args[0]) else { throw CompilationError.badOpcode }
        try testForValidCodeLine(opcode: opcode, value: nil, leadingLabel: nil)
        return ExecutableCode(opcode: opcode)
    }
    
    private func interpretLinesOfCodeWith2Args(_ args: [String]) throws -> ExecutableCode {
        let arg1 = args[0]
        let arg2 = args[1]
        let opcode: Opcode
        var value: Int?
        var leadingLabel: String?
        var trailingLabel: String?
        
        if arg1 == Opcode.data.rawValue {
            guard let opcodeFromArg = Opcode(rawValue: arg1) else { throw CompilationError.badOpcode }
            opcode = opcodeFromArg
            guard let argAsInt = Int(arg2) else { throw CompilationError.intExpected }
            value = argAsInt
        } else if arg2 == Opcode.data.rawValue || arg2 == Opcode.halt.rawValue {
            guard let opcodeFromArg = Opcode(rawValue: arg2) else { throw CompilationError.badOpcode }
            opcode = opcodeFromArg
            leadingLabel = arg1
            value = 0
        } else {
            guard let opcodeFromArg = Opcode(rawValue: arg1) else { throw CompilationError.badOpcode }
            opcode = opcodeFromArg
            trailingLabel = arg2
        }
        
        try testForValidCodeLine(opcode: opcode, value: value, leadingLabel: leadingLabel)
        return ExecutableCode(opcode: opcode, leadingLabel: leadingLabel, trailingLabel: trailingLabel, value: value)
    }
    
    private func interpretLinesOfCodeWith3Args(_ args: [String]) throws -> ExecutableCode {
        guard let opcode = Opcode(rawValue: args[1]) else { throw CompilationError.badOpcode }
        var value: Int?
        var trailingLabel: String?
        let leadingLabel = args[0]
        
        if opcode == .data {
            guard let argAsInt = Int(args[2]) else { throw CompilationError.intExpected }
            value = argAsInt
        } else {
            trailingLabel = args[2]
        }
        
        try testForValidCodeLine(opcode: opcode, value: value, leadingLabel: leadingLabel)
        return ExecutableCode(opcode: opcode, leadingLabel: leadingLabel, trailingLabel: trailingLabel, value: value)
    }
}
