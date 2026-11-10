import SwiftUI
import AntigravityData

@main
public struct AntigravityApp: App {
    @State private var store = AntigravitySessionStore.makeESDDVerificationStore()
    @State private var activeVerifyCase: ESDDVerifySceneCase? = DebugSceneFactory.launchVerifyCase()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            AntigravityRootContainerView(store: store, activeVerifyCase: $activeVerifyCase)
                .preferredColorScheme(.dark)
                .task {
                    guard activeVerifyCase == nil else { return }
                    let env = ProcessInfo.processInfo.environment
                    if let backendURL = env["ANTIGRAVITY_BACKEND_URL"], !backendURL.isEmpty {
                        let csrf = env["ANTIGRAVITY_CSRF_TOKEN"] ?? ""
                        let sha256 = env["ANTIGRAVITY_CERT_SHA256"]
                        _ = await store.connectDirectLAN(
                            endpointURLString: backendURL,
                            csrfToken: csrf,
                            certSHA256: sha256,
                            hostName: env["ANTIGRAVITY_HOST_NAME"] ?? "MacBook Pro"
                        )
                    } else {
                        _ = await store.restoreSavedBackendSession()
                    }
                }
                .onOpenURL { url in
                    if let sceneCase = DebugSceneFactory.resolveDeepLink(url) {
                        activeVerifyCase = sceneCase
                        return
                    }
                    if url.scheme?.lowercased() == "antigravity" && url.host?.lowercased() == "pair" {
                        Task {
                            _ = await store.connectWithPairingURI(url.absoluteString)
                        }
                    }
                }
        }
    }
}
