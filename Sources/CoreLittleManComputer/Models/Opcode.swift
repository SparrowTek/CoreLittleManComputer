public enum Opcode: String {
    case add = "add"
    case subtract = "sub"
    case store = "sta"
    case load = "lda"
    case branch = "bra"
    case branchIfZero = "brz"
    case branchIfPositive = "brp"
    case input = "inp"
    case output = "out"
    case halt = "hlt"
    case data = "dat"
    
    var registerValue: Int {
        switch self {
        case .add: 100
        case .subtract: 200
        case .store: 300
        case .load: 500
        case .branch: 600
        case .branchIfZero: 700
        case .branchIfPositive: 800
        case .input: 901
        case .output: 902
        case .halt, .data: 000
        }
    }
}
