import SwiftUI
import AntigravityData

/// Lightweight compatibility alias forwarding `ArtifactReviewViewController` to `ImplementationPlanReviewViewController` (`UE11`).
public struct ArtifactReviewViewController: View {
    @Bindable public var store: AntigravitySessionStore

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        ImplementationPlanReviewViewController(store: store)
    }
}
