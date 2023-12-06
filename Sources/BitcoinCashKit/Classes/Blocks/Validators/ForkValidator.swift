import BitcoinCore
import Foundation

public class ForkValidator: IBlockChainedValidator {
    private let concreteValidator: IBitcoinCashBlockValidator
    private let forkHeight: Int
    private let expectedBlockHash: Data

    public init(concreteValidator: IBitcoinCashBlockValidator, forkHeight: Int, expectedBlockHash: Data) {
        self.concreteValidator = concreteValidator
        self.forkHeight = forkHeight
        self.expectedBlockHash = expectedBlockHash
    }

    public func validate(block: Block, previousBlock: Block) throws {
        if block.headerHash != expectedBlockHash {
            throw BitcoinCoreErrors.BlockValidation.wrongHeaderHash
        }

        try concreteValidator.validate(block: block, previousBlock: previousBlock)
    }

    public func isBlockValidatable(block: Block, previousBlock _: Block) -> Bool {
        block.height == forkHeight
    }
}
