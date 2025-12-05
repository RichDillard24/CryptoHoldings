import SwiftUI
import CoreData
import Combine

enum NetState: Equatable {case idle, loading, loaded, failed(String) }

@MainActor
final class CryptoVM: ObservableObject {
    @Published var symbols: [String] = []
    @Published var state: NetState = .idle
    @Published var lastUpdated: Date? = nil
    @Published var livePrices: [String: (Double, Date)] = [:]
    
    private let cache = PricesCache()
    private let api: PricesAPI
    private var refreshTask: Task<Void, Never>? = nil
    
    init(useMock: Bool = Bundle.main.infoDictionary?["FREECRYPTO_API_KEY"] as? String == nil)  {
        if useMock { self.api = MockAPI() } else { self.api = FreeCryptoAPI() }
        loadWatchlist()
    }
    func mapNetError(_ error: Error) -> String {
        if let e = error as? URLError {
            switch e.code {
            case .cannotFindHost, .cannotConnectToHost: return "Cannot reach api.freecryptoapi.com."
            case .notConnectedToInternet: return "No internet connection."
            case .timedOut: return "Request timed out."
            default: break
            }
        }
        return error.localizedDescription
    }
    func loadWatchlist() {
        let raw = UserDefaults.standard.array(forKey: "watchlistsymbols") as? [String] ?? ["BTC", "ETH"]
        symbols = Array(raw.prefix(4))
    }
    func saveWatchlist() {
        let limited: [String] = Array(symbols.prefix(4))
        UserDefaults.standard.set(limited, forKey: "wathlistsymbols")
    }
    
    func startRefreshLoop(intervalSec: Int = 15) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            try? Task.checkCancellation()
            await self.refreshAll()
            try? await Task.sleep(nanoseconds: UInt64(intervalSec) * 1_000_000_000)
        }
    }
    
    func stopRefreshLoop() { refreshTask?.cancel(); refreshTask = nil }
    
    func refreshAll() async {
        guard !symbols.isEmpty else { return }
        state = .loading
        do {
            let dict = try await retry(times: 1) { [self] in
                try await api.prices(for: symbols)
            }
            for (s,p) in dict { await cache.set(s, price: p) }
            self.livePrices = await cache.snapshot()
            self.lastUpdated = Date()
        } catch {
            self.state = .failed(error.localizedDescription)
        }
    }
    
    private func retry<T>(times: Int = 1, backoffNS: UInt64 = 600_000_000,
                          _ op: @escaping () async throws -> T) async throws -> T {
        var last: Error?
        for attempt in 0...times {
            do { return try await op()} catch {
                last = error
                if attempt < times { try? await Task.sleep(nanoseconds: backoffNS) }
                
            }
        }
        throw last!
    }
    func price(for symbol: String) -> (Double, Date)? { livePrices[symbol] }
}
    actor PricesCache {
        private var map: [String: (Double, Date)] = [:]
        func set(_ symbol: String, price: Double, at: Date = Date()) { map[symbol] = (price, at) }
        func get(_ symbol: String) -> (Double, Date)? { map[symbol] }
        func snapshot() -> [String: (Double, Date)] {map}
    }


