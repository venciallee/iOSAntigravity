import SwiftUI
import AntigravityData

/// Lightweight compatibility alias forwarding `TurnDiffViewController` to `TurnDiffReviewViewController` (`UE12`).
public struct TurnDiffViewController: View {
    @Bindable public var store: AntigravitySessionStore

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        TurnDiffReviewViewController(store: store)
    }
}
