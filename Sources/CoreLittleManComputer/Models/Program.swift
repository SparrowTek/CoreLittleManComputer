import SwiftUI

public typealias Register = Int

public struct Program {
    public var programCounter: Int = 0
    public var inbox: Int?
    public var outbox: [Int] = []
    public var accumulator: Int = 0
    public var registers = [Register](repeating: 000, count: 100)
    public var printStatement: LocalizedStringResource = ""
    public var registersCurrentlyBeingEvaluated: [Register : Bool] = [:]
}
