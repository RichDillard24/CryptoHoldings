import SwiftUI

struct RootView: View {
    @StateObject private var vm = CryptoVM()
    
    var body: some View {
        TabView {
            HoldingsListView()
                .tabItem { Label("Holdings", systemImage: "chart.line.uptrend.xyaxis")}
                .environmentObject(vm)
            
            WatchListView()
                .tabItem { Label("watchlist", systemImage: "list.bullet") }
                .environmentObject(vm)
        }
        .task { vm.startRefreshLoop() }
        .onAppear{Task{await vm.refreshAll()}}
        .onDisappear { vm.stopRefreshLoop() }
    }
}
