import BitcoinCashKit
import BitcoinCore
import HdWalletKit
import HsToolKit

class BitcoinCashAdapter: BaseAdapter {
    let bitcoinCashKit: Kit

    init(words: [String], testMode: Bool, syncMode: BitcoinCore.SyncMode, logger: Logger) {
        let networkType: Kit.NetworkType = testMode ? .testNet : .mainNet(coinType: .type145)
        guard let seed = Mnemonic.seed(mnemonic: words) else {
            fatalError("Cant make Seed")
        }
        bitcoinCashKit = try! Kit(seed: seed, walletId: "walletId", syncMode: syncMode, networkType: networkType, logger: logger.scoped(with: "BitcoinCashKit"))

        super.init(name: "Bitcoin Cash", coinCode: "BCH", abstractKit: bitcoinCashKit)
        bitcoinCashKit.delegate = self
    }

    class func clear() {
        try? Kit.clear()
    }
}

extension BitcoinCashAdapter: BitcoinCoreDelegate {
    func transactionsUpdated(inserted _: [TransactionInfo], updated _: [TransactionInfo]) {
        transactionsSubject.send()
    }

    func transactionsDeleted(hashes _: [String]) {
        transactionsSubject.send()
    }

    func balanceUpdated(balance _: BalanceInfo) {
        balanceSubject.send()
    }

    func lastBlockInfoUpdated(lastBlockInfo _: BlockInfo) {
        lastBlockSubject.send()
    }

    public func kitStateUpdated(state _: BitcoinCore.KitState) {
        syncStateSubject.send()
    }
}
