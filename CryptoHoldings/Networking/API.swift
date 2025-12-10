import Foundation

protocol PricesAPI {
    func price(for symbol: String) async throws -> Double
    func prices(for symbols: [String]) async throws -> [String: Double]
}

extension URLRequest {
    mutating func setBearer(_ token: String) {
        setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
struct GetDataEnvelope: Decodable {
    let statusString: String?
    let statusBool: Bool?
    let error: String?
    let symbols: [Quote]?

    var isSuccess: Bool {
        if let s = statusString { return s.lowercased() == "success" }
        if let b = statusBool { return b }
        return false
    }

    enum CodingKeys: String, CodingKey { case status, symbols, error }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        statusString = try? c.decode(String.self, forKey: .status)
        statusBool   = try? c.decode(Bool.self,   forKey: .status)
        error        = try? c.decode(String.self, forKey: .error)
        symbols      = try? c.decode([Quote].self, forKey: .symbols)
    }
}//struct GetDataEnvelope: Decodable {
//    let statusString: String?
//    let statusBool: Bool?
//    let error: String?
//    let symbols: [Quote]?
//    
//    var isSuccess: Bool {
//        if let s = statusString { return s.lowercased() == "success"}
//        if let b = statusBool { return b}
//        return false
//    }
//    
//    enum CodingKeys: String, CodingKey { case status, symbols, error }
//    init(from d: Decoder) throws {
//        let c = try d.container(keyedBy: CodingKeys.self)
//        statusString = try? c.decode(String.self, forKey: .status)
//        statusBool = try? c.decode(Bool.self, forKey: .status)
//        symbols = try? c.decode([Quote].self, forKey: .symbols)
//        error = try? c.decode(String.self, forKey: .error)
//    }
//}

struct Quote: Decodable {
    let symbol: String
    let last: Double
    
    enum CodingKeys: String, CodingKey { case symbol, last }
    init(from decoder: Decoder) throws{
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try c.decode(String.self, forKey: .symbol)
        let s = try c.decode(String.self, forKey: .last)
        last = Double(s) ?? 0
    }
}
struct FreeCryptoAPI: PricesAPI{
    let baseURL = URL(string: "https://api.freecryptoapi.com")!
    private let path = "/v1/getData"
    
    private var token: String {
        Bundle.main.infoDictionary?["FREECRYPTO_API_KEY"] as? String ?? ""
    }
    
    func prices(for symbols: [String]) async throws -> [String: Double]{
        
        let joined = symbols.map {$0.uppercased() }.joined(separator: " & ")
        
        var comps = URLComponents(url: baseURL.appendingPathComponent(path),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "symbol", value: joined) ]
        let url = comps.url!
        
        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        req.setBearer(token)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {throw URLError(.badServerResponse)}
        guard (200..<300).contains(http.statusCode) else {
            let body = String (data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "API", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }
        let env = try JSONDecoder().decode(GetDataEnvelope.self, from: data)
        guard env.isSuccess, let quotes = env.symbols else {
            throw NSError(domain:"API", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: env.error ?? "Unexpected response"])
        }
        var out: [String: Double] = [:]
        for q in quotes { out[q.symbol.uppercased()] = q.last }
        return out
    }
    func price(for symbol: String) async throws -> Double {
        try await prices(for: [symbol])[symbol.uppercased()] ?? {
            throw URLError(.cannotDecodeRawData)
        }()
    }
}

struct MockAPI: PricesAPI{
    func price(for symbol: String) async throws -> Double {
        let base: [String: Double] = ["BTC": 45123.45, "ETH": 2338.21, "SOL": 104.40, "ADA": 0.38]
        return base[symbol.uppercased()] ?? Double.random(in: 1...50000)
    }
    func prices(for symbols: [String]) async throws -> [String: Double] {
        var out: [String: Double] = [:]
        for s in symbols { out[s] = try await price(for: s) }
        return out
    }
}
    
 
     


