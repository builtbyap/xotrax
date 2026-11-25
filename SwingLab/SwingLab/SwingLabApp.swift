import SwiftUI

@main
struct SwingLabApp: App {
    @State private var monitor = LaunchMonitorService()
    @State private var store = SessionStore()
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(monitor)
                .environment(store)
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onAppear { monitor.start() }
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            RangeView()
                .tabItem { Label("Range", systemImage: "scope") }
                .tag(AppTab.range)
            TargetRangeView()
                .tabItem { Label("Target", systemImage: "target") }
                .tag(AppTab.targetRange)
            CombineView()
                .tabItem { Label("Combine", systemImage: "trophy") }
                .tag(AppTab.combine)
            CoursesView()
                .tabItem { Label("Courses", systemImage: "flag") }
                .tag(AppTab.courses)
            ProfileView()
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}

#Preview {
    ContentView()
        .environment(LaunchMonitorService())
        .environment(SessionStore())
        .environment(AppState())
        .preferredColorScheme(.dark)
}
