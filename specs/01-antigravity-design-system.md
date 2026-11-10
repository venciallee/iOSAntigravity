# Spec 01: Antigravity iOS Design System & Visual Hierarchy

Status: Approved (Normative ESDD Spec)
Target: iOS 18.0+ (iPhone 16 Pro `393×852pt @3x` & iPad Pro Adaptive Split)

## 1. Design Philosophy: "Obsidian Deep Space & iOS Liquid Glass"

Antigravity iOS bridges the signature **Google DeepMind Antigravity** cosmic dark aesthetic (seen in Desktop `v2.30.0`) with **Apple Human Interface Guidelines (HIG)**:

1. **Obsidian Depth Hierarchy**:
   - **Canvas Ground (`#090B10`)**: True deep-space obsidian background that blends seamlessly into the iPhone 16 Pro bezel and Dynamic Island.
   - **Elevated Surface (`#111520`)**: Grouped blocks, code surfaces, and terminal drawers.
   - **Interactive Card (`#161B29`)**: Evidence blocks, Artifact cards, and modal sheets with a `1px` specular hairline border (`rgba(255, 255, 255, 0.08)`).
   - **Liquid Glass Chrome (`rgba(22, 27, 41, 0.78)` + `UIBlurEffect.Style.systemChromeMaterialDark`)**: Navigation bars, Worktree filter bars, and the floating `ChatComposerView`.

2. **Signal & Semantic Colors**:
   - **Antigravity Brand Accent**: Cosmic Indigo (`#6366F1`) to Violet (`#8B5CF6`) gradient for primary CTAs and active agent indicators; Quantum Cyan (`#06B6D4`) as gradient tail.
   - **Semantic Status Signals**:
     - `RUNNING` (`#38BDF8` Sky Pulse): Streaming tokens or active tool execution.
     - `WAITING` (`#F59E0B` Amber Gate): Step status `CORTEX_STEP_STATUS_WAITING (9)` requiring user approval or `ask_question` input.
     - `DONE` (`#10B981` Emerald): Completed turn, passing test, or diff addition.
     - `ERROR` (`#F43F5E` Rose): Failed command or diff deletion.

## 2. Five-Tier Content & Typography Hierarchy

Following Lody's workspace visual hierarchy discipline and Apple Dynamic Type, every text element maps strictly to one of five semantic roles (never arbitrary font sizes or opacities):

| Tier | Content Scope | Size / Line Height | Weight | Ink Token |
| :--- | :--- | :--- | :--- | :--- |
| **1. Reading** | User prompts, Agent Markdown prose responses | `16pt / 24pt` | `400` (Regular) | `inkReading` (`#F8FAFC`) |
| **2. Evidence** | Modified filenames, Artifact titles (`implementation_plan.md`), Diff counters | `14pt / 20pt` | `500` (Medium) | `inkLabel` (`#E2E8F0`) |
| **3. Process** | Collapsible Thinking summary, Tool calls, Terminal output, Browser Subagent steps | `13pt / 18pt` | `400` (Regular) | `inkSecondary` (`#94A3B8`) |
| **4. Metadata** | Step index, elapsed duration, model/effort badge, host ping RTT | `11pt / 14pt` | `400` (Regular) | `inkTertiary` (`#64748B`) |
| **5. Chrome** | Navigation title, Worktree pills, Composer toolbar buttons, Sheet actions | `13pt / 18pt` | `500` (Medium) | `inkSecondary` / `inkLabel` |

## 3. iOS HIG Touch & Geometry Invariants (Enforced by ESDD Inspector)

- **Minimum Touch Target**: Every interactive button, session row, option card, and approval action MUST have a bounding box of at least `44pt × 44pt` (or `>= 44pt` height for full-width rows).
- **Safe Area Compliance**:
  - Top content clears the `59pt` Dynamic Island / Status Bar safe area inset.
  - Bottom interactive controls clear the `34pt` Home Indicator inset.
- **Zero Overlap & Zero Unintended Truncation**: Interactive controls within the same container must have non-intersecting bounding boxes.
