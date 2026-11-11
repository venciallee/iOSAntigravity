import SwiftUI
import AntigravityData
#if canImport(WebKit) && canImport(UIKit)
import WebKit
import UIKit
#endif

/// Extracts or clears Google Cloud Relay session cookies (`SAPISID`, `__Secure-1PAPISID`, `__Secure-3PAPISID`, `SID`, etc.)
/// from `WKWebsiteDataStore.default()`.
@MainActor
public enum CloudRelayCookieExtractor {
    public static func readGoogleCookieHeader() async -> String? {
        #if canImport(WebKit) && canImport(UIKit)
        let store = WKWebsiteDataStore.default().httpCookieStore
        let allCookies = await store.allCookies()
        let now = Date()
        var pairs: [String] = []
        var seenNames = Set<String>()

        for cookie in allCookies {
            if let expires = cookie.expiresDate, expires <= now {
                continue
            }
            let domain = cookie.domain.lowercased()
            guard domain.hasSuffix("google.com") || domain.contains("antigravity.google") else {
                continue
            }
            // Prefer `.google.com` / `antigravity.google.com` entries first
            let key = "\(cookie.name)=\(cookie.value)"
            if !seenNames.contains(key) {
                seenNames.insert(key)
                pairs.append(key)
            }
        }
        let header = pairs.joined(separator: "; ")
        return SAPISIDHashGenerator.hasRequiredGoogleAuthCookies(header) ? header : nil
        #else
        return nil
        #endif
    }

    public static func clearGoogleCookies() async {
        #if canImport(WebKit) && canImport(UIKit)
        let store = WKWebsiteDataStore.default().httpCookieStore
        let allCookies = await store.allCookies()
        for cookie in allCookies {
            let domain = cookie.domain.lowercased()
            if domain.hasSuffix("google.com") || domain.contains("antigravity.google") {
                await store.deleteCookie(cookie)
            }
        }
        #endif
    }
}

/// Interactive Google Sign-In sheet (`WKWebView`) opening `https://antigravity.google.com/r/<id>`,
/// automatically capturing the authenticated Google cookies to establish native Connect-RPC over
/// `devtools_jetski_boq_api_proto.ApiService`.
public struct CloudRelaySignInSheet: View {
    public let targetRelayURLString: String
    public var onAuthenticated: (_ cookieHeader: String, _ finalURLString: String?, _ authUser: String?) -> Void
    public var onDismiss: () -> Void

    @State private var currentURLDisplay: String = "antigravity.google.com"
    @State private var isLoadingPage: Bool = true
    @State private var detectedCookiesReady: Bool = false

    public init(
        targetRelayURLString: String,
        onAuthenticated: @escaping (_ cookieHeader: String, _ finalURLString: String?, _ authUser: String?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.targetRelayURLString = targetRelayURLString
        self.onAuthenticated = onAuthenticated
        self.onDismiss = onDismiss
    }

    private var initialURL: URL {
        let parsed = RemoteHostInstance.parseRemoteControlTarget(targetRelayURLString)
        let urlStr = parsed?.canonicalRelayURLString ?? SAPISIDHashGenerator.defaultOrigin
        return URL(string: urlStr) ?? URL(string: SAPISIDHashGenerator.defaultOrigin)!
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Chrome Bar
            HStack(spacing: 12) {
                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundStyle(UEChromePalette.textSecondary)
                        .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AntigravityTheme.statusDone)
                        Text("Google Remote Control Sign-In")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    Text(currentURLDisplay)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(UEChromePalette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    Task {
                        if let cookie = await CloudRelayCookieExtractor.readGoogleCookieHeader() {
                            let parsed = RemoteHostInstance.parseRemoteControlTarget(currentURLDisplay)
                            onAuthenticated(cookie, nil, parsed?.authUser)
                        }
                    }
                } label: {
                    Text("Connect")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            detectedCookiesReady
                                ? AntigravityTheme.accentPeriwinkle
                                : UEChromePalette.textMuted
                        )
                        .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
                .disabled(!detectedCookiesReady)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AntigravityTheme.surfaceCard)

            if isLoadingPage {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(AntigravityTheme.accentPeriwinkle)
            }

            #if canImport(WebKit) && canImport(UIKit)
            CloudRelayWebViewRepresentable(
                initialURL: initialURL,
                onStateChange: { urlStr, loading, cookiesReady in
                    if let urlStr {
                        currentURLDisplay = urlStr
                    }
                    isLoadingPage = loading
                    detectedCookiesReady = cookiesReady
                },
                onAutoCapturedSession: { cookieHeader, finalURL, authUser in
                    onAuthenticated(cookieHeader, finalURL, authUser)
                }
            )
            #else
            VStack(spacing: 12) {
                Spacer()
                Text("WebKit Sign-In is available on iOS.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(UEChromePalette.textSecondary)
                Spacer()
            }
            #endif
        }
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
    }
}

#if canImport(WebKit) && canImport(UIKit)
private struct CloudRelayWebViewRepresentable: UIViewControllerRepresentable {
    let initialURL: URL
    let onStateChange: (String?, Bool, Bool) -> Void
    let onAutoCapturedSession: (String, String?, String?) -> Void

    func makeUIViewController(context: Context) -> CloudRelayWebAuthViewController {
        let vc = CloudRelayWebAuthViewController(initialURL: initialURL)
        vc.onStateChange = onStateChange
        vc.onAutoCapturedSession = onAutoCapturedSession
        return vc
    }

    func updateUIViewController(_ uiViewController: CloudRelayWebAuthViewController, context: Context) {}
}

@MainActor
private final class CloudRelayWebAuthViewController: UIViewController, WKNavigationDelegate, WKHTTPCookieStoreObserver {
    private let initialURL: URL
    var onStateChange: ((String?, Bool, Bool) -> Void)?
    var onAutoCapturedSession: ((String, String?, String?) -> Void)?

    private var webView: WKWebView!
    private var didCompleteCapture = false
    private var isObservingCookieStore = false

    init(initialURL: URL) {
        self.initialURL = initialURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let wv = WKWebView(frame: view.bounds, configuration: config)
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wv.navigationDelegate = self
        wv.customUserAgent =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        view.addSubview(wv)
        self.webView = wv

        wv.load(URLRequest(url: initialURL))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !isObservingCookieStore {
            webView.configuration.websiteDataStore.httpCookieStore.add(self)
            isObservingCookieStore = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isObservingCookieStore {
            webView.configuration.websiteDataStore.httpCookieStore.remove(self)
            isObservingCookieStore = false
        }
    }

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor [weak self] in
            await self?.evaluateSessionReadiness(autoFinishIfOnRelayHost: true)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onStateChange?(webView.url?.host ?? initialURL.host, true, false)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            await self?.evaluateSessionReadiness(autoFinishIfOnRelayHost: true)
        }
    }

    private func evaluateSessionReadiness(autoFinishIfOnRelayHost: Bool) async {
        guard !didCompleteCapture else { return }
        let currentURL = webView.url
        let host = currentURL?.host?.lowercased() ?? ""
        let cookieHeader = await CloudRelayCookieExtractor.readGoogleCookieHeader()
        let hasCookies = (cookieHeader != nil)
        onStateChange?(currentURL?.host ?? initialURL.host, webView.isLoading, hasCookies)

        let isOnAntigravityRelay = host.contains("antigravity.google")
        if autoFinishIfOnRelayHost && isOnAntigravityRelay, let cookieHeader {
            didCompleteCapture = true
            let finalURLStr = currentURL?.absoluteString
            let parsed = finalURLStr.flatMap { RemoteHostInstance.parseRemoteControlTarget($0) }
            onAutoCapturedSession?(cookieHeader, finalURLStr, parsed?.authUser)
        }
    }
}
#endif
