import SwiftUI
import AntigravityData

@main
public struct AntigravityApp: App {
    @State private var store = AntigravitySessionStore.makeESDDVerificationStore()
    @State private var activeVerifyCase: ESDDVerifySceneCase?

    public init() {}

    public var body: some Scene {
        WindowGroup {
            AntigravityRootContainerView(store: store, activeVerifyCase: $activeVerifyCase)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    if let sceneCase = DebugSceneFactory.resolveDeepLink(url) {
                        activeVerifyCase = sceneCase
                    } else if let paired = RemoteHostInstance.parseRemoteControlQR(urlString: url.absoluteString) {
                        store.activeHost.instanceId = paired.instanceId
                        if let convId = paired.conversationId {
                            store.activeCascadeId = convId
                        }
                    }
                }
        }
    }
}
