import BigInt
import BitcoinCore
import Foundation
import HdWalletKit
import HsToolKit

public class Kit: AbstractKit {
    private static let name = "BitcoinCashKit"
    private static let svChainForkHeight = 556_767 // 2018 November 14
    private static let bchnChainForkHeight = 661_648 // 2020 November 15, 14:13 GMT
    private static let abcChainForkBlockHash = "0000000000000000004626ff6e3b936941d341c5932ece4357eeccac44e6d56c".reversedData!
    private static let bchnChainForkBlockHash = "0000000000000000029e471c41818d24b8b74c911071c4ef0b4a0509f9b5a8ce".reversedData!

    private static let legacyHeightInterval = 2016 // Default block count in difficulty change circle ( Bitcoin )
    private static let legacyTargetSpacing = 10 * 60 // Time to mining one block ( 10 min. Bitcoin )
    private static let legacyMaxTargetBits = 0x1D00_FFFF // Initially and max. target difficulty for blocks

    private static let heightInterval = 144 // Blocks count in window for calculating difficulty ( BitcoinCash )
    private static let targetSpacing = 10 * 60 // Time to mining one block ( 10 min. same as Bitcoin )
    private static let maxTargetBits = 0x1D00_FFFF // Initially and max. target difficulty for blocks

    public enum NetworkType {
        case mainNet(coinType: CoinType)
        case testNet

        var network: INetwork {
            switch self {
            case let .mainNet(coinType):
                return MainNet(coinType: coinType)
            case .testNet:
                return TestNet()
            }
        }

        var description: String {
            switch self {
            case let .mainNet(coinType):
                switch coinType {
                case .type0: return "mainNet" // back compatibility for database file name in old NetworkType
                case .type145: return "mainNet-145"
                }
            case .testNet:
                return "testNet"
            }
        }
    }

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            bitcoinCore.delegate = delegate
        }
    }

    private init(extendedKey: HDExtendedKey?, watchAddressPublicKey: WatchAddressPublicKey?, walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet(coinType: .type145), confirmationsThreshold: Int = 6, logger: Logger?) throws {
        let network = networkType.network
        let validScheme: String
        switch networkType {
        case .mainNet:
            validScheme = "bitcoincash"
        case .testNet:
            validScheme = "bchtest"
        }

        let logger = logger ?? Logger(minLogLevel: .verbose)
        let databaseFilePath = try DirectoryHelper.directoryURL(for: Kit.name).appendingPathComponent(Kit.databaseFileName(walletId: walletId, networkType: networkType, syncMode: syncMode)).path
        let storage = GrdbStorage(databaseFilePath: databaseFilePath)
        let checkpoint = Checkpoint.resolveCheckpoint(network: network, syncMode: syncMode, storage: storage)
        let apiSyncStateManager = ApiSyncStateManager(storage: storage, restoreFromApi: network.syncableFromApi && syncMode != BitcoinCore.SyncMode.full)

        let apiTransactionProvider: IApiTransactionProvider?
        let hsBlockHashFetcher = HsBlockHashFetcher(hsUrl: "https://api.blocksdecoded.com/v1/blockchains/bitcoin-cash", logger: logger)

        switch networkType {
        case .mainNet:
            let apiTransactionProviderUrl = "https://api.haskoin.com/bch/blockchain"
            if case let .blockchair(key) = syncMode {
                let blockchairApi = BlockchairApi(secretKey: key, chainId: network.blockchairChainId, logger: logger)
                let blockchairBlockHashFetcher = BlockchairBlockHashFetcher(blockchairApi: blockchairApi)
                let blockHashFetcher = BlockHashFetcher(hsFetcher: hsBlockHashFetcher, blockchairFetcher: blockchairBlockHashFetcher, checkpointHeight: checkpoint.block.height)

                apiTransactionProvider = BlockchairTransactionProvider(blockchairApi: blockchairApi, blockHashFetcher: blockHashFetcher)
            } else {
                apiTransactionProvider = BlockchainComApi(url: apiTransactionProviderUrl, blockHashFetcher: hsBlockHashFetcher, logger: logger)
            }
        case .testNet:
            apiTransactionProvider = BlockchainComApi(url: "https://api.haskoin.com/bchtest/blockchain", blockHashFetcher: hsBlockHashFetcher, logger: logger)
        }

        let paymentAddressParser = PaymentAddressParser(validScheme: validScheme, removeScheme: false)
        let difficultyEncoder = DifficultyEncoder()

        let blockValidatorSet = BlockValidatorSet()
        blockValidatorSet.add(blockValidator: ProofOfWorkValidator(difficultyEncoder: difficultyEncoder))

        let blockValidatorChain = BlockValidatorChain()
        let coreBlockHelper = BlockValidatorHelper(storage: storage)
        let blockHelper = BitcoinCashBlockValidatorHelper(coreBlockValidatorHelper: coreBlockHelper)

        let daaValidator = DAAValidator(encoder: difficultyEncoder, blockHelper: blockHelper, targetSpacing: Kit.targetSpacing, heightInterval: Kit.heightInterval)
        let asertValidator = ASERTValidator(encoder: difficultyEncoder)

        switch networkType {
        case .mainNet:
            blockValidatorChain.add(blockValidator: ForkValidator(concreteValidator: asertValidator, forkHeight: Kit.bchnChainForkHeight, expectedBlockHash: Kit.bchnChainForkBlockHash))
            blockValidatorChain.add(blockValidator: asertValidator)
            blockValidatorChain.add(blockValidator: ForkValidator(concreteValidator: daaValidator, forkHeight: Kit.svChainForkHeight, expectedBlockHash: Kit.abcChainForkBlockHash))
            blockValidatorChain.add(blockValidator: daaValidator)
            blockValidatorChain.add(blockValidator: LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockValidatorHelper: coreBlockHelper, heightInterval: Kit.legacyHeightInterval, targetTimespan: Kit.legacyTargetSpacing * Kit.legacyHeightInterval, maxTargetBits: Kit.legacyMaxTargetBits))
            blockValidatorChain.add(blockValidator: EDAValidator(encoder: difficultyEncoder, blockHelper: blockHelper, blockMedianTimeHelper: BlockMedianTimeHelper(storage: storage), maxTargetBits: Kit.legacyMaxTargetBits))
        case .testNet: ()
            // not use test validators
        }

        blockValidatorSet.add(blockValidator: blockValidatorChain)

        let bitcoinCore = try BitcoinCoreBuilder(logger: logger)
            .set(network: network)
            .set(apiTransactionProvider: apiTransactionProvider)
            .set(checkpoint: checkpoint)
            .set(apiSyncStateManager: apiSyncStateManager)
            .set(extendedKey: extendedKey)
            .set(watchAddressPublicKey: watchAddressPublicKey)
            .set(paymentAddressParser: paymentAddressParser)
            .set(walletId: walletId)
            .set(confirmationsThreshold: confirmationsThreshold)
            .set(peerSize: 10)
            .set(syncMode: syncMode)
            .set(storage: storage)
            .set(blockValidator: blockValidatorSet)
            .set(purpose: .bip44)
            .build()

        super.init(bitcoinCore: bitcoinCore, network: network)
    }

    public convenience init(extendedKey: HDExtendedKey, walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet(coinType: .type145), confirmationsThreshold: Int = 6, logger: Logger?) throws {
        try self.init(extendedKey: extendedKey, watchAddressPublicKey: nil,
                      walletId: walletId,
                      syncMode: syncMode,
                      networkType: networkType,
                      confirmationsThreshold: confirmationsThreshold,
                      logger: logger)

        // extending BitcoinCore
        let bech32AddressConverter = CashBech32AddressConverter(prefix: network.bech32PrefixPattern)
        bitcoinCore.prepend(addressConverter: bech32AddressConverter)

        let restoreKeyConverter: IRestoreKeyConverter
        if case .blockchair = syncMode {
            restoreKeyConverter = BlockchairCashRestoreKeyConverter(addressConverter: bech32AddressConverter, prefix: network.bech32PrefixPattern)
        } else {
            let base58 = Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash)
            restoreKeyConverter = Bip44RestoreKeyConverter(addressConverter: base58)
        }

        bitcoinCore.add(restoreKeyConverter: restoreKeyConverter)
    }

    public convenience init(watchAddress: String, walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet(coinType: .type145), confirmationsThreshold: Int = 6, logger: Logger?) throws {
        let network = networkType.network
        let base58AddressConverter = Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash)
        let bech32AddressConverter = CashBech32AddressConverter(prefix: network.bech32PrefixPattern)
        let parserChain = AddressConverterChain()
        parserChain.prepend(addressConverter: base58AddressConverter)
        parserChain.prepend(addressConverter: bech32AddressConverter)

        let address = try parserChain.convert(address: watchAddress)
        let publicKey = try WatchAddressPublicKey(data: address.lockingScriptPayload, scriptType: address.scriptType)

        try self.init(extendedKey: nil, watchAddressPublicKey: publicKey,
                      walletId: walletId,
                      syncMode: syncMode,
                      networkType: networkType,
                      confirmationsThreshold: confirmationsThreshold,
                      logger: logger)

        bitcoinCore.prepend(addressConverter: bech32AddressConverter)

        let restoreKeyConverter: IRestoreKeyConverter
        if case .blockchair = syncMode {
            restoreKeyConverter = BlockchairCashRestoreKeyConverter(addressConverter: bech32AddressConverter, prefix: network.bech32PrefixPattern)
        } else {
            let base58 = Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash)
            restoreKeyConverter = Bip44RestoreKeyConverter(addressConverter: base58)
        }

        bitcoinCore.add(restoreKeyConverter: restoreKeyConverter)
    }

    public convenience init(seed: Data, walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet(coinType: .type145), confirmationsThreshold: Int = 6, logger: Logger?) throws {
        let masterPrivateKey = HDPrivateKey(seed: seed, xPrivKey: Purpose.bip44.rawValue)

        try self.init(extendedKey: .private(key: masterPrivateKey),
                      walletId: walletId,
                      syncMode: syncMode,
                      networkType: networkType,
                      confirmationsThreshold: confirmationsThreshold,
                      logger: logger)
    }
}

extension Kit {
    public static func clear(exceptFor walletIdsToExclude: [String] = []) throws {
        try DirectoryHelper.removeAll(inDirectory: Kit.name, except: walletIdsToExclude)
    }

    private static func databaseFileName(walletId: String, networkType: NetworkType, syncMode: BitcoinCore.SyncMode) -> String {
        "\(walletId)-\(networkType.description)-\(syncMode)"
    }
}
