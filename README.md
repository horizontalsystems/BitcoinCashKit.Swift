# BitcoinCashKit.Swift

`BitcoinCashKit.Swift` is a package that extends [BitcoinCore.Swift](https://github.com/horizontalsystems/BitcoinCore.Swift) and makes it usable with `BitcoinCash (ABC)` Mainnet and Testnet networks. 

## Features

- [x] `Base58` and `Bech32`
- [x] Validation of BCH hard forks
- [x] `ASERT`, `DAA`, `EDA` validations


## Usage

Because BitcoinCash is a fork of Bitcoin, the usage of this package does not differ much from `BitcoinKit.Swift`. So here, we only describe some differences between these packages. For more usage documentation, please see [BitcoinKit.Swift](https://github.com/horizontalsystems/BitcoinKit.Swift)

### Initialization

All BitcoinCash wallets use default [BIP44](https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki) derivation path where *coinType* is `145` according to [SLIP44](https://github.com/satoshilabs/slips/blob/master/slip-0044.md). But since it's a fork of Bitcoin, `0` coinType also can be restored.

```swift
let seed = Mnemonic.seed(mnemonic: [""], passphrase: "")!

let bitcoinCashKit = try BitcoinCashKit.Kit(
        seed: seed,
        walletId: "unique_wallet_id",
        syncMode: .full,
        networkType: .mainNet(coinType: .type145),
        confirmationsThreshold: 3,
        logger: nil
)
```
## Prerequisites

* Xcode 10.0+
* Swift 5+
* iOS 13+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/horizontalsystems/BitcoinCashKit.Swift.git", .upToNextMajor(from: "1.0.0"))
]
```

## Example Project

All features of the library are used in example project. It can be referred as a starting point for usage of the library.

## License

The `BitcoinCashKit` toolkit is open source and available under the terms of the [MIT License](https://github.com/horizontalsystems/BitcoinCashKit.Swift/blob/master/LICENSE).

