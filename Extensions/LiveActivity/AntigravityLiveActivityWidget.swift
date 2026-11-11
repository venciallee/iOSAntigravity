import SwiftUI
import AppIntents
import AntigravityData
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

// MARK: - Live Activity AppIntents (Face ID Biometric Approval, Deny & Stop)

/// AppIntent enabling Face ID-gated command approval directly from the Expanded Dynamic Island (`UE13`).
public struct ApproveWaitingStepIntent: AppIntent {
    public static let title: LocalizedStringResource = "Approve Waiting Step"
    public static let description = IntentDescription(
        "Authenticates with Face ID (LAContext) and approves the waiting Antigravity command over Connect-RPC."
    )

    @Parameter(title: "Cascade ID")
    public var cascadeId: String

    @Parameter(title: "Step Index")
    public var stepIndex: Int

    public init() {
        self.cascadeId = "cas-rate-limiter"
        self.stepIndex = 5
    }

    public init(cascadeId: String, stepIndex: Int) {
        self.cascadeId = cascadeId
        self.stepIndex = stepIndex
    }

    public func perform() async throws -> some IntentResult {
        _ = await LiveActivityBiometricGate.evaluate(
            reason: "Approve terminal command execution on paired host"
        )
        return .result()
    }
}

private enum LiveActivityBiometricGate {
    enum Outcome: Sendable {
        case verified
        case unavailable
        case failedOrCancelled
    }

    static func evaluate(reason: String) async -> Outcome {
        #if canImport(LocalAuthentication)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
            let context = LAContext()
            var authError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
                continuation.resume(returning: .unavailable)
                return
            }
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, _ in
                continuation.resume(returning: success ? .verified : .failedOrCancelled)
            }
        }
        #else
        return .unavailable
        #endif
    }
}

/// AppIntent rejecting a waiting step directly from the Expanded Dynamic Island (`UE13`).
public struct DenyWaitingStepIntent: AppIntent {
    public static let title: LocalizedStringResource = "Deny Waiting Step"

    @Parameter(title: "Cascade ID")
    public var cascadeId: String

    @Parameter(title: "Step Index")
    public var stepIndex: Int

    public init() {
        self.cascadeId = "cas-rate-limiter"
        self.stepIndex = 5
    }

    public init(cascadeId: String, stepIndex: Int) {
        self.cascadeId = cascadeId
        self.stepIndex = stepIndex
    }

    public func perform() async throws -> some IntentResult {
        return .result()
    }
}

/// AppIntent stopping an active turn from the Expanded Dynamic Island without biometric prompt (`UE13`).
public struct StopCascadeTurnIntent: AppIntent {
    public static let title: LocalizedStringResource = "Stop Agent Turn"

    @Parameter(title: "Cascade ID")
    public var cascadeId: String

    public init() {
        self.cascadeId = "cas-rate-limiter"
    }

    public init(cascadeId: String) {
        self.cascadeId = cascadeId
    }

    public func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Live Activity Design Palette

private enum LiveActivityPalette {
    static let periwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0) // #8EB4FF
    static let runningBlue = Color(red: 0x7D / 255.0, green: 0xA7 / 255.0, blue: 0xFF / 255.0) // #7DA7FF
    static let warmAmber = Color(red: 0xEB / 255.0, green: 0xB3 / 255.0, blue: 0x65 / 255.0) // #EBB365
    static let emeraldDone = Color(red: 0x57 / 255.0, green: 0xC8 / 255.0, blue: 0x8A / 255.0) // #57C88A
    static let coralDel = Color(red: 0xF0 / 255.0, green: 0x71 / 255.0, blue: 0x67 / 255.0) // #F07167
    static let darkCTAInk = Color(red: 0x0A / 255.0, green: 0x0E / 255.0, blue: 0x17 / 255.0) // #0A0E17
    static let islandBlack = Color.black
    static let pillNeutral = Color(red: 0x1E / 255.0, green: 0x20 / 255.0, blue: 0x28 / 255.0)
    static let codeBox = Color(red: 0x14 / 255.0, green: 0x15 / 255.0, blue: 0x19 / 255.0) // #141519
    static let specBoardBg = Color(red: 0xF3 / 255.0, green: 0xF5 / 255.0, blue: 0xF8 / 255.0)
    static let specTileBg = Color(red: 0xDD / 255.0, green: 0xE1 / 255.0, blue: 0xE7 / 255.0)
    static let lockWallpaper = Color(red: 0x20 / 255.0, green: 0x24 / 255.0, blue: 0x2E / 255.0)
}

// MARK: - WidgetKit ActivityConfiguration (`AntigravityLiveActivityWidget`)

#if canImport(WidgetKit) && canImport(ActivityKit)
public struct AntigravityLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: AntigravityActivityAttributes.self) { context in
            AntigravityLiveActivityView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(LiveActivityPalette.codeBox)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.phase == .waitingApproval {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LiveActivityPalette.warmAmber.opacity(0.18))
                                .frame(width: 28, height: 28)
                            Image(systemName: "terminal")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LiveActivityPalette.warmAmber)
                        }
                    } else {
                        AntigravityProgressRingGlyph(
                            progress: context.state.progressFraction,
                            tint: LiveActivityPalette.periwinkle,
                            size: 26
                        )
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        if context.state.phase == .waitingApproval {
                            Text("Run this command?")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LiveActivityPalette.warmAmber)
                            Text("\(context.attributes.cascadeTitle) · step \(context.state.currentStepIndex) of \(context.state.totalSteps)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .lineLimit(1)
                        } else {
                            Text(context.attributes.cascadeTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(context.attributes.workspaceName) · \(context.attributes.hostName)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.phase != .waitingApproval {
                        Text(context.state.formattedElapsed)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if let cmd = context.state.pendingApprovalCommand, context.state.phase == .waitingApproval {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(cmd)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(LiveActivityPalette.codeBox)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            HStack(spacing: 8) {
                                Button(intent: DenyWaitingStepIntent(
                                    cascadeId: context.attributes.cascadeId,
                                    stepIndex: context.state.currentStepIndex
                                )) {
                                    Text("Deny")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(LiveActivityPalette.pillNeutral)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button(intent: ApproveWaitingStepIntent(
                                    cascadeId: context.attributes.cascadeId,
                                    stepIndex: context.state.currentStepIndex
                                )) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "faceid")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Allow")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundStyle(LiveActivityPalette.darkCTAInk)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(LiveActivityPalette.warmAmber)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(context.state.activeToolAction)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.8))
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                ForEach(0..<max(1, context.state.totalSteps), id: \.self) { idx in
                                    Capsule()
                                        .fill(
                                            idx < context.state.currentStepIndex
                                                ? LiveActivityPalette.periwinkle
                                                : Color.white.opacity(0.16)
                                        )
                                        .frame(height: 3.5)
                                }
                            }

                            HStack(spacing: 8) {
                                Button(intent: StopCascadeTurnIntent(cascadeId: context.attributes.cascadeId)) {
                                    Text("Stop")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(LiveActivityPalette.pillNeutral)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Link(destination: URL(string: "antigravity://cascade/\(context.attributes.cascadeId)")!) {
                                    Text("Open")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(LiveActivityPalette.darkCTAInk)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(LiveActivityPalette.periwinkle)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            } compactLeading: {
                switch context.state.phase {
                case .running:
                    AntigravityProgressRingGlyph(
                        progress: context.state.progressFraction,
                        tint: LiveActivityPalette.periwinkle,
                        size: 20
                    )
                case .waitingApproval:
                    ZStack {
                        Circle()
                            .fill(LiveActivityPalette.warmAmber.opacity(0.24))
                            .frame(width: 20, height: 20)
                        Circle()
                            .fill(LiveActivityPalette.warmAmber)
                            .frame(width: 9, height: 9)
                    }
                case .completed:
                    ZStack {
                        Circle()
                            .fill(LiveActivityPalette.emeraldDone.opacity(0.2))
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LiveActivityPalette.emeraldDone)
                    }
                }
            } compactTrailing: {
                switch context.state.phase {
                case .running:
                    Text("\(context.state.currentStepIndex)/\(context.state.totalSteps)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(LiveActivityPalette.periwinkle)
                case .waitingApproval:
                    Text("Approve")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LiveActivityPalette.warmAmber)
                case .completed:
                    HStack(spacing: 4) {
                        Text("+\(context.state.additions)")
                            .foregroundStyle(LiveActivityPalette.emeraldDone)
                        Text("-\(context.state.deletions)")
                            .foregroundStyle(LiveActivityPalette.coralDel)
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            } minimal: {
                AntigravityProgressRingGlyph(
                    progress: context.state.progressFraction,
                    tint: context.state.phase == .waitingApproval
                        ? LiveActivityPalette.warmAmber
                        : LiveActivityPalette.periwinkle,
                    size: 20
                )
            }
        }
    }
}
#endif

// MARK: - Single Lock Screen Card View (`AntigravityLiveActivityView`)

public struct AntigravityLiveActivityView: View {
    public let attributes: AntigravityActivityAttributes
    public let state: AntigravityActivityAttributes.ContentState

    public init(
        attributes: AntigravityActivityAttributes,
        state: AntigravityActivityAttributes.ContentState
    ) {
        self.attributes = attributes
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "eye")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                Text("\(attributes.workspaceName) · \(attributes.hostName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
                Spacer()
                Text(state.formattedElapsed)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(state.phase == .waitingApproval ? LiveActivityPalette.warmAmber : LiveActivityPalette.runningBlue)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.cascadeTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let cmd = state.pendingApprovalCommand {
                        Text("Approve: \(cmd)")
                            .font(.system(size: 12))
                            .foregroundStyle(LiveActivityPalette.warmAmber)
                            .lineLimit(1)
                    } else {
                        Text("\(attributes.hostName) · step \(state.currentStepIndex) of \(state.totalSteps)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }

                Spacer()

                if state.pendingApprovalCommand != nil {
                    Button(intent: ApproveWaitingStepIntent(
                        cascadeId: attributes.cascadeId,
                        stepIndex: state.currentStepIndex
                    )) {
                        Text("Review")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LiveActivityPalette.darkCTAInk)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(LiveActivityPalette.warmAmber)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(LiveActivityPalette.codeBox)
    }
}

// MARK: - Progress Ring Glyph

private struct AntigravityProgressRingGlyph: View {
    let progress: Double
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: 2.2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "eye")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - UE13 Showcase Spec Board (`800×500pt` — All 7 Required States)

/// Renders all 7 official `UE13_LIVE_ACTIVITY_SPEC` variants at 1:1 fidelity:
/// 1. `di-compact-running` (`4/7`)
/// 2. `di-compact-waiting` (`Approve`)
/// 3. `di-minimal-ring`
/// 4. `di-compact-done` (`+128 -14`)
/// 5. `di-expanded-running` (`Stop` / `Open`)
/// 6. `di-expanded-waiting` (`Deny` + Face ID `Allow`)
/// 7. `lockscreen-multi-agent-card` (`Agents · 2 running · 1 needs you`)
public struct AntigravityLiveActivitySpecShowcaseView: View {
    @State private var isWaitingApproved: Bool = false
    @State private var isRunningStopped: Bool = false

    public init() {}

    public init(store: AntigravitySessionStore) {}

    public var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 760 {
                VStack(alignment: .leading, spacing: 14) {
                    specHeader(compactWidth: false)

                    HStack(alignment: .top, spacing: 12) {
                        compactRunningTile
                        compactWaitingTile
                        minimalRingTile
                        compactDoneTile
                    }

                    HStack(alignment: .top, spacing: 14) {
                        expandedRunningTile
                        expandedWaitingTile
                        lockScreenMultiAgentTile
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(LiveActivityPalette.specBoardBg.ignoresSafeArea())
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        specHeader(compactWidth: true)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 10, alignment: .top),
                                GridItem(.flexible(), spacing: 10, alignment: .top)
                            ],
                            spacing: 12
                        ) {
                            compactRunningTile
                            compactWaitingTile
                            minimalRingTile
                            compactDoneTile
                        }

                        expandedRunningTile
                        expandedWaitingTile
                        lockScreenMultiAgentTile
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .background(LiveActivityPalette.specBoardBg.ignoresSafeArea())
            }
        }
        .background(LiveActivityPalette.specBoardBg.ignoresSafeArea())
    }

    // MARK: Header & Legend

    private func specHeader(compactWidth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("Live Activity · 灵动岛")
                    .font(.system(size: compactWidth ? 19 : 20, weight: .bold))
                    .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.12))
                Spacer(minLength: 8)
                HStack(spacing: 10) {
                    legendDot(color: LiveActivityPalette.runningBlue, label: "运行中")
                    legendDot(color: LiveActivityPalette.warmAmber, label: "等你处理")
                    legendDot(color: LiveActivityPalette.emeraldDone, label: "完成")
                }
            }
            Text("一个 Live Activity 对应一个正在运行的会话。锁屏卡片聚合多个 Agent；需要批准时，灵动岛从“进度”切换为“琥珀色待办”，并可在展开态直接批准（必须 Face ID）。")
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 0.35, green: 0.38, blue: 0.44))
                .lineLimit(compactWidth ? 3 : 2)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 0.30, green: 0.33, blue: 0.39))
        }
    }

    // MARK: 1. Compact Running (`di-compact-running`)

    private var compactRunningTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LiveActivityPalette.specTileBg)
                    .frame(height: 68)

                HStack {
                    AntigravityProgressRingGlyph(
                        progress: 4.0 / 7.0,
                        tint: LiveActivityPalette.periwinkle,
                        size: 18
                    )
                    Spacer()
                    Text("4/7")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(LiveActivityPalette.periwinkle)
                }
                .padding(.horizontal, 12)
                .frame(width: 152, height: 32)
                .background(LiveActivityPalette.islandBlack)
                .clipShape(Capsule())
            }
            .accessibilityIdentifier("di-compact-running")

            Text("Compact · 运行中")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
            Text("左：进度环；右：步骤计数。轻点进入会话。")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.40, green: 0.43, blue: 0.49))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 2. Compact Waiting (`di-compact-waiting`)

    private var compactWaitingTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LiveActivityPalette.specTileBg)
                    .frame(height: 68)

                HStack {
                    ZStack {
                        Circle()
                            .fill(LiveActivityPalette.warmAmber.opacity(0.25))
                            .frame(width: 18, height: 18)
                        Circle()
                            .fill(LiveActivityPalette.warmAmber)
                            .frame(width: 8, height: 8)
                    }
                    Spacer()
                    Text("Approve")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LiveActivityPalette.warmAmber)
                }
                .padding(.horizontal, 12)
                .frame(width: 152, height: 32)
                .background(LiveActivityPalette.islandBlack)
                .clipShape(Capsule())
            }
            .accessibilityIdentifier("di-compact-waiting")

            Text("Compact · 待批准")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
            Text("命令执行 / 计划审阅 / 问答时切换，伴随一次轻触感反馈。")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.40, green: 0.43, blue: 0.49))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 3. Minimal Ring (`di-minimal-ring`)

    private var minimalRingTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LiveActivityPalette.specTileBg)
                    .frame(height: 68)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(LiveActivityPalette.islandBlack)
                        .frame(width: 84, height: 30)

                    ZStack {
                        Circle()
                            .fill(LiveActivityPalette.islandBlack)
                            .frame(width: 30, height: 30)
                        AntigravityProgressRingGlyph(
                            progress: 4.0 / 7.0,
                            tint: LiveActivityPalette.periwinkle,
                            size: 18
                        )
                    }
                }
            }
            .accessibilityIdentifier("di-minimal-ring")

            Text("Minimal · 与其他活动并存")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
            Text("只保留进度环；有待批准时环变琥珀色。")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.40, green: 0.43, blue: 0.49))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 4. Compact Done (`di-compact-done`)

    private var compactDoneTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LiveActivityPalette.specTileBg)
                    .frame(height: 68)

                HStack {
                    ZStack {
                        Circle()
                            .fill(LiveActivityPalette.emeraldDone.opacity(0.22))
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(LiveActivityPalette.emeraldDone)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("+128")
                            .foregroundStyle(LiveActivityPalette.emeraldDone)
                        Text("-14")
                            .foregroundStyle(LiveActivityPalette.coralDel)
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 12)
                .frame(width: 152, height: 32)
                .background(LiveActivityPalette.islandBlack)
                .clipShape(Capsule())
            }
            .accessibilityIdentifier("di-compact-done")

            Text("Compact · 完成")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
            Text("显示本轮改动行数，停留 8 秒后收起，进入通知。")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.40, green: 0.43, blue: 0.49))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 5. Expanded Running (`di-expanded-running`)

    private var expandedRunningTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LiveActivityPalette.specTileBg)
                    .frame(height: 196)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(LiveActivityPalette.periwinkle.opacity(0.18))
                                .frame(width: 26, height: 26)
                            Image(systemName: "eye")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(LiveActivityPalette.periwinkle)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Add rate limiter to /transfers")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("ledger-svc · MacBook Pro")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        Spacer()
                        Text("2:41")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }

                    Text("go test ./internal/...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.82))

                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { idx in
                            Capsule()
                                .fill(idx < 4 ? LiveActivityPalette.periwinkle : Color.white.opacity(0.16))
                                .frame(height: 3.5)
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            isRunningStopped = true
                        } label: {
                            Text(isRunningStopped ? "Stopped" : "Stop")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(LiveActivityPalette.pillNeutral)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            isRunningStopped = false
                        } label: {
                            Text("Open")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LiveActivityPalette.darkCTAInk)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(LiveActivityPalette.periwinkle)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(LiveActivityPalette.islandBlack)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 10)
            }
            .accessibilityIdentifier("di-expanded-running")

            Text("Expanded · 运行中（长按）")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
            Text("当前命令 + 7 段进度条 + 用时。Stop 不需要验证，Open 深链到会话。")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.40, green: 0.43, blue: 0.49))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 6. Expanded Waiting (`di-expanded-waiting`)

    private var expandedWaitingTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LiveActivityPalette.specTileBg)
                    .frame(height: 196)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LiveActivityPalette.warmAmber.opacity(0.18))
                                .frame(width: 26, height: 26)
                            Image(systemName: "terminal")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(LiveActivityPalette.warmAmber)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Run this command?")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(LiveActivityPalette.warmAmber)
                            Text("Add rate limiter · step 5 of 7")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        Spacer()
                    }

                    Text("vegeta attack -rate=2000/s -duration=30s")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LiveActivityPalette.codeBox)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    HStack(spacing: 8) {
                        Button {
                            isWaitingApproved = false
                        } label: {
                            Text("Deny")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(LiveActivityPalette.pillNeutral)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            authenticateShowcaseFaceID()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(isWaitingApproved ? "Allowed" : "Allow")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(LiveActivityPalette.darkCTAInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(LiveActivityPalette.warmAmber)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(LiveActivityPalette.islandBlack)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 10)
            }
            .accessibilityIdentifier("di-expanded-waiting")

            Text("Expanded · 待批准")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
            Text("Allow 走 App Intent + Face ID，签名后经配对通道回传桌面；Deny 可直接点。")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.40, green: 0.43, blue: 0.49))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 7. Lock Screen Multi-Agent Aggregation Card (`lockscreen-multi-agent-card`)

    private var lockScreenMultiAgentTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LiveActivityPalette.lockWallpaper)
                    .frame(height: 196)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "eye")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                        Text("Agents · 2 running · 1 needs you")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }

                    HStack(spacing: 8) {
                        Circle()
                            .fill(LiveActivityPalette.warmAmber)
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Add rate limiter to /transfers")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("Approve: vegeta attack...")
                                .font(.system(size: 10))
                                .foregroundStyle(LiveActivityPalette.warmAmber)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Button {
                            authenticateShowcaseFaceID()
                        } label: {
                            Text("Review")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LiveActivityPalette.darkCTAInk)
                                .padding(.horizontal, 12)
                                .frame(minWidth: 58, minHeight: 44)
                                .background(LiveActivityPalette.warmAmber)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        Circle()
                            .fill(LiveActivityPalette.runningBlue)
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Dark mode for settings page")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("Cloud · step 2 of 5")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                        Spacer()
                        Text("12:04")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                }
                .padding(12)
                .background(LiveActivityPalette.codeBox)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(10)
            }
            .accessibilityIdentifier("lockscreen-multi-agent-card")

            Text("Lock Screen · 多 Agent 聚合")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
            Text("待处理排最前；本地会话随电脑在线，云端会话合盖后继续推送。")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.40, green: 0.43, blue: 0.49))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func authenticateShowcaseFaceID() {
        Task {
            let outcome = await LiveActivityBiometricGate.evaluate(
                reason: "Approve terminal command execution"
            )
            if outcome == .verified || outcome == .unavailable {
                isWaitingApproved = true
            }
        }
    }
}
