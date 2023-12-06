import BigInt
import BitcoinCore
import Foundation

// BitcoinCore Compatibility

public protocol IBitcoinCashDifficultyEncoder {
    func decodeCompact(bits: Int) -> BigInt
    func encodeCompact(from bigInt: BigInt) -> Int
}

public protocol IBitcoinCashHasher {
    func hash(data: Data) -> Data
}

public protocol IBitcoinCashBlockValidator {
    func validate(block: Block, previousBlock: Block) throws
    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool
}

// ###############################

public protocol IBitcoinCashBlockValidatorHelper {
    func suitableBlockIndex(for blocks: [Block]) -> Int?

    func previous(for block: Block, count: Int) -> Block?
    func previousWindow(for block: Block, count: Int) -> [Block]?
}

public protocol IBlockValidatorHelperWrapper {
    func previous(for block: Block, count: Int) -> Block?
    func previousWindow(for block: Block, count: Int) -> [Block]?
}

public protocol IBitcoinCashBlockMedianTimeHelper {
    var medianTimePast: Int? { get }
    func medianTimePast(block: Block) -> Int?
}
