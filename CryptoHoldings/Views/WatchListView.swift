import SwiftUI


struct WatchListView: View {
    @EnvironmentObject var vm: CryptoVM
    @State private var newSymbol: String = ""
    
    var body: some View {
        NavigationStack {
            List{
                Section("Add Symbol (max 4)"){
                    HStack{
                        TextField("e.g. BTC", text: $newSymbol)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                        Button("Add") { add() }.disabled(!canAdd)
                    }
                    Text("Current: \(vm.symbols.joined(separator: ", "))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Manager") {
                    ForEach(vm.symbols, id: \.self) { s in
                        HStack{
                            Text(s).font(.headline)
                            Spacer()
                            Button(role: .destructive) { remove(s) } label: { Image(systemName: "trash") }
                        }
                    }
                }
            }
            .navigationTitle("WatchList")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh Now") { Task { await vm.refreshAll()} }
                }
            }
        }
    }
    private var canAdd: Bool {
        let s = newSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return !s.isEmpty && vm.symbols.count < 4 && !vm.symbols.contains(s)
    }
    private func add() {
        let s = newSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !s.isEmpty else { return }
        vm.symbols.removeAll { $0 == s }; vm.saveWatchlist()
    }
    
}
