import Foundation


struct HoldingDTO: Codable, Hashable {
    var symbol: String
    var buyPrice: Double
    var buyAtISO: String
    var currentPrice: Double?
    var currentAtISO: String?
    var note: String?
    
    static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
