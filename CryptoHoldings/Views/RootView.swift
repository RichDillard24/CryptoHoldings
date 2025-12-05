import SwiftUI

struct RootView: View {
    @StateObject private var vm = CryptoVM()
    
    var body: some View {
        
            NavigationStack {
                Group {
                    switch vm.state {
                    case .idle, .loading:
                        ProgressView()
                        
                        Text("loading...")
                        
                    case .loaded:
                        List(vm.) {  in
                            Text(post.title)
                            Text(post.body)
                        }
                    case .failed:
                        Text()
                   
                    }
                }
                .navigationTitle(Text("Posts"))
                .refreshable {
                    await vm.load()
                }
                .task{
                    await vm.load()
                }
            }
        }    }
}
