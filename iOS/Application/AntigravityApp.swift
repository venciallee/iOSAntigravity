import SwiftUI
import AntigravityData

@main
public struct AntigravityApp: App {
    @State private var store: AntigravitySessionStore
    @State private var activeVerifyCase: ESDDVerifySceneCase?

    public init() {
        let initialStore = AntigravitySessionStore.makeESDDVerificationStore()
        let launchCase = DebugSceneFactory.launchVerifyCase()
        if let launchCase {
            initialStore.configureForVerifyScene(launchCase)
        }
        self._store = State(initialValue: initialStore)
        self._activeVerifyCase = State(initialValue: launchCase)
    }

    public var body: some Scene {
        WindowGroup {
            AntigravityRootContainerView(store: store, activeVerifyCase: $activeVerifyCase)
                .preferredColorScheme(activeVerifyCase == .liveActivitySpec ? .light : .dark)
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
                        store.configureForVerifyScene(sceneCase)
                        activeVerifyCase = sceneCase
                        return
                    }
                    if url.scheme?.lowercased() == "antigravity" && url.host?.lowercased() == "pair" {
                        Task {
                            let ok = await store.connectWithPairingURI(url.absoluteString)
                            if ok {
                                store.activeRoute = .tabRoot
                            }
                        }
                    }
                }
        }
    }
}
