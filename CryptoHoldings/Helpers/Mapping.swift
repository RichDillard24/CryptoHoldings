import CoreData


func makeDTOs(from holdings: [Holding], currentPrice: (String) ->(Double, Date)?) -> [HoldingDTO] {
    holdings.compactMap { h in
        guard let symbol = h.symbol, let buyAt = h.buyAt else { return nil }
        let cur = currentPrice(symbol)
        return HoldingDTO(symbol: symbol,
                          buyPrices: h.buyPrice,
                          buyAtISO: HoldingDTO.iso(buyAt),
                          currentPrice: cur?.0,
                          currentAtISO: cur.map { HoldingDTO.iso($0.1) },
                          note: h.note)
    }
}
func upsertHolding(from dto: HoldingDTO, in ctx: NSManagedObjectContext){
    
    let req: NSFetchRequest<Holding> = Holding.fetchRequest()
    req.predicate = NSPredicate(format: "symbol == %@ AND buyAt ==%@", dto.symbol, ISO8601DateFormatter().date(from:
        dto.buyAtISO)! as NSDate)
    req.fetchLimit = 1
    let existing = (try? ctx.fetch(req))?.first
    let h = existing ?? Holding(context: ctx)
    h.id = h.id ?? UUID() as NSObject as! UUID
    h.symbol = dto.symbol
    h.buyPrice = dto.buyPrice
    h.buyAt = ISO8601DateFormatter().date(from: dto.buyAtISO)
    h.note = dto.note
}
