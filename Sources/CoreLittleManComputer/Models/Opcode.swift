enum Opcode: String {
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
}
