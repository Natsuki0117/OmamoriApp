import SwiftUI

@main
struct OmamoriAppApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).preferredColorScheme(.light)
        }
    }
}
