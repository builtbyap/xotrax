import Foundation
import Observation

enum AppTab: Hashable {
    case range, targetRange, combine, courses, profile
}

/// Shared UI state. Every tab stays alive inside the TabView, so modes check
/// `tab` before recording a shot — only the visible mode captures it.
@Observable
final class AppState {
    var tab: AppTab = .range
}
