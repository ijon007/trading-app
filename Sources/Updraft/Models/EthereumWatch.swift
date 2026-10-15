import Foundation

/// Read-only Ethereum lookups for watch accounts, using free endpoints with no key:
/// - ethereum-rpc.publicnode.com (JSON-RPC, batched eth_getBalance + ERC-20 balanceOf),
/// - api.ensideas.com for optional ENS name resolution.
enum EthereumWatch {
    enum WatchError: LocalizedError {
        case invalidAddress, ensNotFound, network

        var errorDescription: String? {
            switch self {
            case .invalidAddress: "Enter a valid Ethereum address (0x followed by 40 hex characters) or an ENS name."
            case .ensNotFound: "That ENS name doesn't resolve to an address."
            case .network: "Couldn't reach the Ethereum network. Try again."
            }
        }
    }

    static let rpcURL = URL(string: "https://ethereum-rpc.publicnode.com")!

    /// Major ERC-20 tokens we look up, with our coin symbol and decimals.
    static let tokens: [(symbol: String, contract: String, decimals: Int)] = [
        ("USDC", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
        ("USDT", "0xdAC17F958D2ee523a2206206994597C13D831ec7", 6),
        ("WBTC", "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", 8),
        ("LINK", "0x514910771AF9Ca656af840dff83E8264EcF986CA", 18),
        ("UNI", "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984", 18),
        ("SHIB", "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE", 18),
        ("DAI", "0x6B175474E89094C44Da98b954EedeAC495271d0F", 18),
        ("PEPE", "0x6982508145454Ce325dDbE47a25d4ec3d2311933", 18),
    ]

    /// `0x` plus 40 hex characters (checksum casing isn't enforced).
    static func isValidAddress(_ text: String) -> Bool {
        let s = text.trimmingCharacters(in: .whitespaces)
        guard s.count == 42, s.lowercased().hasPrefix("0x") else { return false }
        return s.dropFirst(2).allSatisfy(\.isHexDigit)
    }

    /// Accepts a 0x address or an ENS name (name.eth) and returns the address.
    static func resolve(_ input: String) async throws -> String {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidAddress(s) { return s }
        guard s.lowercased().hasSuffix(".eth"), s.count > 4,
              let encoded = s.lowercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.ensideas.com/ens/resolve/\(encoded)") else { throw WatchError.invalidAddress }
        struct Response: Decodable { let address: String? }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { throw WatchError.network }
        guard let address = (try? JSONDecoder().decode(Response.self, from: data))?.address,
              isValidAddress(address) else { throw WatchError.ensNotFound }
        return address
    }

    /// ETH plus the token list, in whole units, for one address. Zero balances are dropped.
    static func balances(of address: String) async throws -> [(symbol: String, amount: Double)] {
        guard isValidAddress(address) else { throw WatchError.invalidAddress }
        let padded = String(repeating: "0", count: 24) + address.dropFirst(2).lowercased()
        var calls: [[String: Any]] = [[
            "jsonrpc": "2.0", "id": 0, "method": "eth_getBalance", "params": [address, "latest"],
        ]]
        for (i, token) in tokens.enumerated() {
            calls.append([
                "jsonrpc": "2.0", "id": i + 1, "method": "eth_call",
                "params": [["to": token.contract, "data": "0x70a08231" + padded], "latest"],
            ])
        }
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: calls)
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { throw WatchError.network }
        struct Reply: Decodable { let id: Int; let result: String? }
        guard let replies = try? JSONDecoder().decode([Reply].self, from: data) else { throw WatchError.network }
        var out: [(symbol: String, amount: Double)] = []
        for reply in replies.sorted(by: { $0.id < $1.id }) {
            guard let hex = reply.result else { continue }
            let raw = parseHex(hex)
            if reply.id == 0 {
                if raw > 0 { out.append(("ETH", raw / 1e18)) }
            } else if reply.id - 1 < tokens.count {
                let token = tokens[reply.id - 1]
                let amount = raw / pow(10, Double(token.decimals))
                if amount > 0 { out.append((token.symbol, amount)) }
            }
        }
        return out
    }

    /// Hex quantity to Double (precision is plenty for display).
    static func parseHex(_ hex: String) -> Double {
        var value = 0.0
        for c in hex.lowercased().dropFirst(hex.lowercased().hasPrefix("0x") ? 2 : 0) {
            guard let d = c.hexDigitValue else { continue }
            value = value * 16 + Double(d)
        }
        return value
    }
}
