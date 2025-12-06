import SwiftUI
import CoreData

struct HoldingFormView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vm: CryptoVM
    
    @State private var symbol: String = ""
    @State private var buyPrice: String = ""
    @State private var buyAt: Date = Date()
    @State private var note: String = ""
    
    let editing: Holding?
    
    var body: some View {
        NavigationStack{
            Form {
                Section("symbol"){
                    TextField("BTC,ETH, SOL...", text: $symbol)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section("Buy Price") {
                    TextField("e.g 42000.00", text: $buyPrice)
                        .keyboardType(.decimalPad)
                }
                Section("Buy Date") {
                    DatePicker("Date", selection: $buyAt, displayedComponents: [.date,. hourAndMinute])
                }
                Section("Note") {
                    TextEditor(text: $note).frame(minHeight: 120)
                }
            }
            .navigationTitle(editing == nil ? "New Holding" : "Edit Holding")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {Button("Cancel") { dismiss()} }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }.disabled(symbol.trimmingCharacters(in: .whitespaces).isEmpty || Double(buyPrice) == nil)
                    }
                }
            }
                .onAppear {
                    if let h = editing {
                        symbol = h.symbol ?? ""
                        buyPrice = String(format: "%.2f", h.buyPrice)
                        buyAt = h.buyAt ?? Date()
                        note = h.note ?? ""
                    }
                }
            }
        
    private func save() {
        let s = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !s.isEmpty, let price = Double(buyPrice) else { return }
        
        let h = editing ?? Holding(context: ctx)
        if h.id == nil { h.id = UUID() as NSObject as? UUID }
        h.symbol = s
        h.buyPrice = price
        h.buyAt = buyAt
        h.note = note.isEmpty ? nil : note
        
        if !vm.symbols.contains(s) && vm.symbols.count < 4 {
            vm.symbols.append(s); vm.saveWatchlist()
        }
        do { try ctx.save(); dismiss() } catch { print("Svae error:", error) }
    }
}
