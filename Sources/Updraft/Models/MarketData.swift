import Foundation
import Observation

/// Live quote for one coin, in USD.
struct Quote: Sendable, Equatable {
    var price: Double
    var open24h: Double?
    var marketCap: Double?

    var change24h: Double {
        guard let open24h, open24h > 0 else { return 0 }
        return (price - open24h) / open24h * 100
    }
}

enum MarketStatus: Sendable, Equatable { case connecting, live, offline }

/// Real market data without API keys:
/// - Coinbase Exchange WebSocket `ticker` for live prices and 24h change,
/// - Coinbase Exchange candles REST for chart history per timeframe,
/// - CoinGecko `/coins/markets` for market caps and as a price fallback.
///
/// Socket ticks are buffered and published at most once a second, so views
/// observing `quotes` redraw calmly instead of on every trade.
///
/// Mutations only happen on the main actor; reads are allowed anywhere
/// (sample-data helpers read it from nonisolated code), hence `@unchecked Sendable`.
@Observable
final class MarketStore: @unchecked Sendable {
    static let shared = MarketStore()

    private(set) var quotes: [String: Quote] = [:]
    private(set) var status: MarketStatus = .connecting
    /// True once any real price has arrived (socket or CoinGecko).
    private(set) var hasLoaded = false
    private var candleStore: [String: [PricePoint]] = [:]
    private var failedCandles: Set<String> = []

    @ObservationIgnored private var pending: [String: Quote] = [:]
    @ObservationIgnored private var inflight: Set<String> = []
    @ObservationIgnored private var candleLoadedAt: [String: Date] = [:]
    @ObservationIgnored private var socketTask: Task<Void, Never>?
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var lastGecko: Date = .distantPast
    @ObservationIgnored private var active = false

    /// Our symbols to CoinGecko ids. Coinbase product ids are "<SYMBOL>-USD".
    static let geckoIDs: [String: String] = [
        "BTC": "bitcoin", "ETH": "ethereum", "SOL": "solana", "XRP": "ripple",
        "ADA": "cardano", "AVAX": "avalanche-2", "LINK": "chainlink", "DOT": "polkadot",
    ]

    private static var symbols: [String] { geckoIDs.keys.sorted() }

    // MARK: Lifecycle

    /// Starts streaming. Safe to call repeatedly.
    @MainActor func start() {
        guard !active else { return }
        active = true
        Task { await loadGeckoIfStale() }
        socketTask = Task { await runSocket() }
        flushTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                flush()
            }
        }
    }

    /// Stops streaming (app in background). Keeps the last known data.
    @MainActor func stop() {
        guard active else { return }
        active = false
        socketTask?.cancel(); socketTask = nil
        flushTask?.cancel(); flushTask = nil
        flush()
    }

    @MainActor private func flush() {
        guard !pending.isEmpty else { return }
        var next = quotes
        for (symbol, quote) in pending {
            var merged = quote
            merged.marketCap = quote.marketCap ?? quotes[symbol]?.marketCap
            merged.open24h = quote.open24h ?? quotes[symbol]?.open24h
            next[symbol] = merged
        }
        pending = [:]
        quotes = next
        if !hasLoaded { hasLoaded = true }
    }

    // MARK: WebSocket

    @MainActor private func runSocket() async {
        var attempt = 0
        while active && !Task.isCancelled {
            do {
                try await streamOnce()
                attempt = 0
            } catch {
                // Fall through to backoff.
            }
            guard active, !Task.isCancelled else { return }
            status = .offline
            await loadGeckoIfStale()
            attempt += 1
            let delay = min(30, pow(2, Double(min(attempt, 5)))) * Double.random(in: 0.8...1.2)
            try? await Task.sleep(for: .seconds(delay))
        }
    }

    @MainActor private func streamOnce() async throws {
        if quotes.isEmpty { status = .connecting }
        let socket = URLSession.shared.webSocketTask(with: URL(string: "wss://ws-feed.exchange.coinbase.com")!)
        socket.resume()
        try await withTaskCancellationHandler {
            let subscribe: [String: Any] = [
                "type": "subscribe",
                "product_ids": Self.symbols.map { "\($0)-USD" },
                "channels": ["ticker"],
            ]
            let data = try JSONSerialization.data(withJSONObject: subscribe)
            try await socket.send(.string(String(decoding: data, as: UTF8.self)))
            while !Task.isCancelled {
                let message = try await socket.receive()
                let text: String
                switch message {
                case .string(let s): text = s
                case .data(let d): text = String(decoding: d, as: UTF8.self)
                @unknown default: continue
                }
                handle(text)
            }
        } onCancel: {
            socket.cancel(with: .goingAway, reason: nil)
        }
    }

    private struct Ticker: Decodable {
        let type: String
        let product_id: String?
        let price: String?
        let open_24h: String?
    }

    @MainActor private func handle(_ text: String) {
        guard let ticker = try? JSONDecoder().decode(Ticker.self, from: Data(text.utf8)),
              ticker.type == "ticker",
              let product = ticker.product_id,
              let price = ticker.price.flatMap(Double.init) else { return }
        let symbol = String(product.split(separator: "-").first ?? "")
        pending[symbol] = Quote(price: price, open24h: ticker.open_24h.flatMap(Double.init), marketCap: nil)
        if status != .live { status = .live }
    }

    // MARK: CoinGecko

    private struct GeckoCoin: Decodable {
        let id: String
        let current_price: Double?
        let market_cap: Double?
        let price_change_percentage_24h: Double?
    }

    /// Market caps for all coins, and prices for any coin the socket hasn't
    /// covered yet. At most once a minute (free tier is rate limited).
    @MainActor private func loadGeckoIfStale() async {
        guard Date.now.timeIntervalSince(lastGecko) > 60 else { return }
        lastGecko = .now
        let ids = Self.geckoIDs.values.sorted().joined(separator: ",")
        guard let url = URL(string: "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=\(ids)&price_change_percentage=24h"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let coins = try? JSONDecoder().decode([GeckoCoin].self, from: data) else { return }
        let bySymbol = Dictionary(uniqueKeysWithValues: Self.geckoIDs.map { ($0.value, $0.key) })
        var next = quotes
        for coin in coins {
            guard let symbol = bySymbol[coin.id] else { continue }
            if var existing = next[symbol] {
                existing.marketCap = coin.market_cap ?? existing.marketCap
                next[symbol] = existing
            } else if let price = coin.current_price {
                let open = coin.price_change_percentage_24h.map { price / (1 + $0 / 100) }
                next[symbol] = Quote(price: price, open24h: open, marketCap: coin.market_cap)
            }
        }
        quotes = next
        if !hasLoaded && !next.isEmpty { hasLoaded = true }
    }

    // MARK: Candles

    private static func key(_ symbol: String, _ timeframe: Timeframe) -> String { "\(symbol)|\(timeframe.rawValue)" }

    /// Loaded candle closes for a coin and timeframe, oldest first.
    func candles(for symbol: String, _ timeframe: Timeframe) -> [PricePoint]? {
        candleStore[Self.key(symbol, timeframe)]
    }

    /// True when history failed to load (offline or not listed); callers fall back.
    func candlesUnavailable(_ symbol: String, _ timeframe: Timeframe) -> Bool {
        failedCandles.contains(Self.key(symbol, timeframe))
    }

    /// True when loaded history is older than five minutes.
    func candlesStale(_ symbol: String, _ timeframe: Timeframe) -> Bool {
        guard let at = candleLoadedAt[Self.key(symbol, timeframe)] else { return true }
        return Date.now.timeIntervalSince(at) > 300
    }

    /// Requests history if missing or older than five minutes. Dedupes in-flight loads.
    func requestCandles(_ symbol: String, _ timeframe: Timeframe) {
        Task { @MainActor in self.loadCandles(symbol, timeframe) }
    }

    @MainActor private func loadCandles(_ symbol: String, _ timeframe: Timeframe) {
        let key = Self.key(symbol, timeframe)
        if let at = candleLoadedAt[key], Date.now.timeIntervalSince(at) < 300 { return }
        guard !inflight.contains(key) else { return }
        inflight.insert(key)
        Task {
            defer { inflight.remove(key) }
            do {
                let points = try await Self.fetchCandles(product: "\(symbol)-USD", timeframe: timeframe)
                guard !points.isEmpty else { throw URLError(.zeroByteResource) }
                candleStore[key] = points
                candleLoadedAt[key] = .now
                failedCandles.remove(key)
            } catch {
                if candleStore[key] == nil { failedCandles.insert(key) }
                // Retry later rather than hammering.
                candleLoadedAt[key] = Date.now.addingTimeInterval(-240)
            }
        }
    }

    /// Granularity (seconds) and span per timeframe; Coinbase returns at most
    /// 300 candles per request, so long spans are paged.
    static func plan(_ timeframe: Timeframe) -> (granularity: Int, span: TimeInterval) {
        switch timeframe {
        case .hour: (60, 3_600)
        case .day: (300, 86_400)
        case .week: (3_600, 7 * 86_400)
        case .month: (21_600, 30 * 86_400)
        case .year: (86_400, 365 * 86_400)
        case .all: (86_400, 4 * 365 * 86_400)
        }
    }

    nonisolated static func fetchCandles(product: String, timeframe: Timeframe) async throws -> [PricePoint] {
        let (granularity, span) = plan(timeframe)
        let end = Date.now
        let start = end.addingTimeInterval(-span)
        let page = TimeInterval(granularity * 300)
        let iso = ISO8601DateFormatter()
        var rows: [Int: Double] = [:]
        var cursor = start
        while cursor < end {
            let pageEnd = min(cursor.addingTimeInterval(page), end)
            var components = URLComponents(string: "https://api.exchange.coinbase.com/products/\(product)/candles")!
            components.queryItems = [
                URLQueryItem(name: "granularity", value: String(granularity)),
                URLQueryItem(name: "start", value: iso.string(from: cursor)),
                URLQueryItem(name: "end", value: iso.string(from: pageEnd)),
            ]
            var request = URLRequest(url: components.url!)
            request.setValue("Updraft/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            // [time, low, high, open, close, volume], newest first.
            let candles = try JSONDecoder().decode([[Double]].self, from: data)
            for c in candles where c.count >= 5 { rows[Int(c[0])] = c[4] }
            cursor = pageEnd
        }
        return rows.keys.sorted().map { PricePoint(date: Date(timeIntervalSince1970: TimeInterval($0)), price: rows[$0]!) }
    }
}
