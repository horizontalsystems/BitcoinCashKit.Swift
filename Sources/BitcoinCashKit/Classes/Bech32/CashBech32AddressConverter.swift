import BitcoinCore
import Foundation

public class CashBech32AddressConverter: IAddressConverter {
    private let prefix: String

    public init(prefix: String) {
        self.prefix = prefix
    }

    public func convert(address: String) throws -> Address {
        var correctedAddress = address
        if address.firstIndex(of: ":") == nil {
            correctedAddress = "\(prefix):\(address)"
        }
        if let cashAddrData = CashAddrBech32.decode(correctedAddress) {
            guard prefix == cashAddrData.prefix else {
                throw BitcoinCoreErrors.AddressConversion.wrongAddressPrefix
            }
            // extract type from version byte and check data size
            // first bit must be zero. Next 4 bits - address type, where 0 - pubkeyHash, 8 - scriptHash
            // last 3 bits - size of data. where 0 - 20 byte(used Ripemd160), each next - more on 4 or 8 bytes (used Ripemd192, 224, 256, 320, 384, 448, 512)

            let versionByte = cashAddrData.data[0]
            let typeBits = (versionByte & 0b0111_1000)
            let sizeOffset = (versionByte & 0b0000_0100) >> 2 == 1
            let size = 20 + (sizeOffset ? 20 : 0) + (versionByte & 0b0000_0011) * (sizeOffset ? 8 : 4) // first 3 value with steps by 4, than by 8

            let hex = cashAddrData.data.dropFirst()
            guard hex.count == size else {
                throw BitcoinCoreErrors.AddressConversion.invalidAddressLength
            }
            let type = AddressType(rawValue: typeBits) ?? .pubKeyHash
            return CashAddress(type: type, payload: hex, cashAddrBech32: correctedAddress, version: versionByte)
        }
        throw BitcoinCoreErrors.AddressConversion.unknownAddressType
    }

    public func convert(lockingScriptPayload: Data, type: ScriptType) throws -> Address {
        let addressType: AddressType
        switch type {
        case .p2pkh, .p2pk:
            addressType = AddressType.pubKeyHash
        case .p2sh:
            addressType = AddressType.scriptHash
        default: throw BitcoinCoreErrors.AddressConversion.unknownAddressType
        }
        var versionByte = addressType.rawValue
        // make version byte use rules in convert address method
        let sizeOffset = lockingScriptPayload.count >= 40
        let divider = sizeOffset ? 8 : 4
        let size = lockingScriptPayload.count - (sizeOffset ? 20 : 0) - 20
        if size % divider != 0 {
            throw BitcoinCoreErrors.AddressConversion.invalidAddressLength
        }
        versionByte = versionByte + (sizeOffset ? 1 : 0) << 2 + UInt8(size / divider)
        let bech32 = CashAddrBech32.encode(Data([versionByte]) + lockingScriptPayload, prefix: prefix)
        return CashAddress(type: addressType, payload: lockingScriptPayload, cashAddrBech32: bech32, version: versionByte)
    }

    public func convert(publicKey: PublicKey, type: ScriptType) throws -> Address {
        try convert(lockingScriptPayload: publicKey.hashP2pkh, type: type)
    }
}
