import SwiftUI
import CoreData

struct HoldingsListView: View {
    @EnvironmentObject private var vm: CryptoVM
    @Environment(\.managedObjectContext) private var ctx
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Holding.buyAt, ascending: false)],
        animation: .default
    ) private var holdings: FetchedResults<Holding>
    
    @State private var showEditor = false
    @State private var editing: Holding? = nil
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDoc: JSONFile? = nil
    @State private var alertMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            List{
                Section{
                    ForEach(holdings) { h in
                        HoldingRow(h: h, pricePair: vm.price(for: h.symbol ?? ""))
                            .contentShape(Rectangle())
                            .onTapGesture { editing = h; showEditor = true}
                    }
                    .onDelete(perform: .deleteItems)
                } header: {
                    HStack{
                        Text("Your Holdings")
                        Spacer()
                        if let ts = vm.lastUpdated {
                            Text(ts, style: .time)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay{
                switch vm.state {
                case .loading:
                    ProgressView().controlSize(.large)
                case .failed(let msg):
                    VStack(spacing: 8){
                        Text("Network Error").bold()
                        Text(msg).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { Task { await vm.refreshAll() } }
                    }
                    .padding().background(.ultraThinMaterial).clipShap(RoundedRectangle(cornerRadius: 12))
                default: EmptyView()
                }
            }
            .navigationTitle("Crypto Tracker")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { editing = nil; showEditor = true} label: { Image(systemName: "plus.circle.fill") }
                    Button { export() } label: { Image(systemName: "square.and.arrow.up") }
                    Button { isImporting = true } label: { Image(systemName: "square.and.arrow.down") }
                }
            }
            .fileExporter(isPresented: $isExporting, document: exportDoc, contentType: .json, defaultFilename:
                            "holdings.json") { result in
                if case .failure(let err) = result { alertMessage = "Failed to Export: \(err.localizedDescription)"}
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                do{
                    let url = try result.get()
                    let data = try Data(contentsOf: url)
                    let dtos = try JSONDecoder().decode([HoldingDTO].self, from: data)
                    try importDTOs(dtos)
                } catch {
                    alertMessage = "Import Failed: \(error.localizedDescription)"
                }
            }
            .sheet(isPresented: $showEditor) {
                HoldingFormView(editing: editing)
                    .environmentObject(vm)
            }
            .alert("Notice", isPresented: .constant(alertMessage != nil)) {
                Button("Ok") { alertMessage = nil }
            } message: { Text(alertMessage ?? "")}
        }
    }
    private func deletItems(at offsets: IndexSet) {
        offsets.map { holdings[$0] }.forEach(ctx.delete)
        try? ctx.save()
    }
    private func export() {
        let list = Array(holdings)
        let dtos = makeDTOs(from: list) { sym in vm.price(for: sym) }
        do { exportDoc = JSONFile(data: try JSONEncoder().encode(dtos)); isExporting = true}
        catch { alertMessage = "Export Failed: \(error.localizedDescription)"}
    }
    private func importDTOs(_ dtos: [HoldingDTO]) throws {
        for dto in dtos { upsertHolding(from: dto, in: ctx) }
        try ctx.save()
    }
}

struct HoldingRow: View {
    let h: Holding
    let pricePair: (Double, Date)?
    
    var body: some View {
        HStack( spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Text(h.symbol ?? "--").font(.headline)
                if let note = h.note, !note.isEmpty {
                    Text(note).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                if let dt = h.buyAt {
                    Text(dt, style: .date).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let pair = pricePair {
                    let cur = pair.0
                    let delta = cur - h.buyPrice
                    let pct = h.buyPrice != 0 ? (delta / h.buyPrice) * 100 : 0
                    Text(String(format: "$%.2f", cur)).font(.body).monospacedDigit()
                    Text(String(format: "%+.2f (%+.2f%%)", delta, pct))
                        .font(.footnote).monospacedDigit()
                        .foregroundStyle(delta >= 0 ? .green : .red)
                } else {
                    Text("--").foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
