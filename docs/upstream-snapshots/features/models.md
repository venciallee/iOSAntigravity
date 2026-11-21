Choose a model2-0Antigravity AppGet StartedChoose a model Antigravity App Get StartedAntigravity AppAntigravity CLIIDE ExtensionsAntigravity IDE

Available on:Antigravity AppAntigravity CLIIDE extensionsAntigravity IDE

# Choose a model
Section titled “Choose a model”

Antigravity gives you access to leading frontier reasoning models from Google DeepMind and partner providers. You can switch models at any time and choose a thinking level (Low, Medium, High, or Extra on supported models) to balance response speed for quick edits against deeper multi-step reasoning for complex architecture and debugging tasks. To pair a top-tier planner model with a faster executor model in the same conversation, select Orchestrator.

## Select a model
Section titled “Select a model”

You can select which reasoning model you want to use from the model selector menu under the conversation prompt box:

Model

Gemini Models
Weekly Limit Remaining

100%

Five Hour Limit Remaining

100%

Claude and GPT models
Weekly Limit Remaining

100%

Five Hour Limit Remaining

100%

† Available with paid Google AI Pro plans or on trial with eligible premium devices. To switch to a paid Google AI Pro plan, submit a request.

‡ In Gemini Enterprise, Orchestrator only runs Gemini 4 Carbon (High) as the planner paired with Gemini 4 Hydrogen (High) as the executor; custom planner and executor selection is available on Google AI Pro and Google AI Ultra only.

Most adjustable Gemini models offer Low, Medium (default), and High thinking levels. Gemini 4 Neon and Gemini 4 Hydrogen add a fourth level labeled Extra in the model selector, which sets the Extra High reasoning budget (xhigh in the Antigravity CLI, such as --model gemini-4-neon-xhigh or --effort xhigh) when a task needs maximum reasoning depth.

Your choice of reasoning model persists between messages within a conversation. If you change the reasoning model while the agent is running, it continues to use the previously selected reasoning model until it completes its steps for that turn (or until you cancel the current execution).

## Reasoning model
Section titled “Reasoning model”

For the core reasoning model, Antigravity offers leading frontier models. Availability depends on your plan:

ModelFree & Google AI PlusGoogle AI ProGoogle AI UltraEnterprise

Gemini 4 Neon❌✅†✅✅

Gemini 4 Carbon❌❌✅✅

Gemini 4 Argon❌✅†✅✅

Gemini 4 Hydrogen❌✅**✅✅

Orchestrator❌✅†✅✅‡

Gemini 3.8 Flash✅✅✅✅

Gemini 3.7 Flash❌❌❌✅

Gemini 3.6 Flash❌❌❌✅

Gemini 3.1 Pro❌❌❌✅

Claude Sonnet 5.5 (thinking)**❌✅**✅✅

Claude Opus 5.5 (thinking)**❌✅**✅✅

Claude Sonnet 4.6 (thinking)*✅✅❌❌

Claude Opus 4.6 (thinking)*✅✅❌❌

GPT-OSS-120b*✅✅✅❌

* Will be removed on November 30, 2026.

** Available on Google AI Pro for non-trial subscriptions only. To cancel your trial and switch to a paid Google AI Pro plan, submit a request.

† Available with paid Google AI Pro plans or on trial with eligible premium devices. To switch to a paid Google AI Pro plan, submit a request.

‡ In Gemini Enterprise, Orchestrator only runs Gemini 4 Carbon (High) as the planner paired with Gemini 4 Hydrogen (High) as the executor; custom planner and executor selection is available on Google AI Pro and Google AI Ultra only.

To learn more about reasoning model rate limits, refer to the plans page. If you are using Antigravity with Gemini Enterprise, see Supported models in Gemini Enterprise.

### Gemini 4 Neon
Section titled “Gemini 4 Neon”

Gemini 4 Neon appears at the top of the model selector on every plan that includes it. It’s the default model for new conversations if you haven’t chosen a model; if you’ve already selected one, Antigravity keeps your selection. You can switch to any other model at any time.

- Thinking levels: Low, Medium (default), High, and Extra. In the Antigravity CLI, these are low, medium, high, and xhigh (for example, --model gemini-4-neon-xhigh).

- Context window: Up to 512K tokens.

- Availability: Google AI Ultra, Google AI Pro (paid plans, or trials with eligible premium devices), and Gemini Enterprise. Gemini 4 Neon isn’t available on Free and Plus plans.

- Orchestrator: On Google AI Ultra and Google AI Pro, select Orchestrator to plan with Gemini 4 Neon and hand implementation steps to a faster executor (in Gemini Enterprise, Orchestrator only pairs Gemini 4 Carbon with Gemini 4 Hydrogen).

## Orchestrator
Section titled “Orchestrator”

Orchestrator is a model selector option available on Google AI Ultra, Google AI Pro (paid plans, or trials with eligible premium devices), and Gemini Enterprise that pairs two models in a single conversation: a larger orchestrator (planner) model plans and reviews the work, while a faster executor model carries out searches, file edits, builds, and tests.

On Google AI Ultra and Google AI Pro in the Antigravity App, you can choose the model and thinking level for each role under Settings > Models > Orchestrator Settings, or hover Orchestrator in the model selector to override the planner for a single conversation:

RoleResponsibilitiesSupported models

Orchestrator Model (planner)Explores the codebase, writes the plan, and reviews progressGemini 4 Neon (default), Gemini 4 Carbon, Gemini 4 Argon, Claude Opus 5.5

Executor ModelSearches, edits files, runs builds and testsGemini 4 Hydrogen (default), Claude Sonnet 5.5

Available models and thinking levels match your plan (refer to the reasoning model table). In the Antigravity CLI on Google AI Ultra and Google AI Pro, /model offers a single Orchestrator row with a Planner selector (Neon, Carbon on Google AI Ultra, or Argon) paired with Gemini 4 Hydrogen.

Each planner and executor model is also available as a standalone option in the model selector, depending on your plan. Orchestrator coordinates them automatically, so you get top-tier planning quality while finishing faster and using fewer tokens than running the planner alone.

Orchestrator isn’t a router that classifies your prompt upfront and sends the whole request to a single model. Instead, both models collaborate within the same task and hand control back and forth as the work unfolds:

- The orchestrator model plans. Each message you send starts with a read-only planning phase in which the planner explores the codebase, resolves ambiguities, and writes a concrete implementation plan, including the conditions that should trigger re-planning. If your message is a question, review, or explanation that doesn’t need changes, the planner answers it directly; for small follow-ups whose steps are already settled, it hands off a short plan right away.

- The executor model does the work. Once the plan is ready, the executor (such as Gemini 4 Hydrogen) takes over to search, apply file edits, write code, run builds and tests, and verify the results against the plan.

- Control returns when something unexpected happens. If the executor runs into friction, such as a verification step that fails twice, an interface that behaves differently than expected, or a design choice the plan didn’t settle, it hands control back to the planner, which inspects the conversation state, repairs the plan, and hands execution back to the executor.

- The orchestrator model reviews progress. On longer tasks, and whenever you send a message while the executor is working, the executor reports its progress to the planner, which checks what was done against the plan and then wraps up the completed task, continues the remaining steps, or updates the plan.

These hand-offs happen automatically within a single response, so you don’t need to switch models manually between planning and execution. To run every step on a single model, select that model directly in the model selector. Availability depends on your plan; refer to the reasoning model table.

### Select Orchestrator
Section titled “Select Orchestrator”

- Antigravity App

- Antigravity CLI

### Antigravity App
Section titled “Antigravity App”

-
Click the model selector under the conversation prompt box.

-
Click Orchestrator to select it. On Google AI Ultra and Google AI Pro, clicking Orchestrator uses your active Orchestrator Model from Settings > Models > Orchestrator Settings (shown next to Orchestrator, such as Gemini 4 Neon Medium), or you can hover Orchestrator to pick a planner model and thinking level for the current conversation only.

Selecting Orchestrator in the Antigravity App: open the model selector under the prompt box, hover the New badge on Orchestrator to view its summary, open the Orchestrator submenu to pick Gemini 4 Carbon High as the planner for the conversation, and type a task.

To change the default Orchestrator Model and Executor Model used across new Orchestrator conversations, open Settings > Models and update Orchestrator Settings:

Like any other model, Orchestrator stays selected for the rest of the conversation until you choose a different model. Custom orchestrator and executor model selection in the App applies to local conversations.

### Antigravity CLI
Section titled “Antigravity CLI”

Selecting Orchestrator in the Antigravity CLI: complete /model with Tab, highlight the Orchestrator row, use the Left and Right arrow keys on the Planner bar to choose Carbon, confirm with Enter, and check that /effort doesn't apply to it.

You can select Orchestrator in any of the following ways:

-
Interactive picker: Run /model, highlight Orchestrator (on Google AI Ultra and Google AI Pro, use ← / → or Tab to choose a Planner: Neon, Carbon on Google AI Ultra, or Argon), and press Enter. Your choice persists across sessions.

-
At startup: Pass the model’s name or identifier when you launch the CLI or run it in headless mode (use --model gemini-pro-orchestrator in Gemini Enterprise):

agy --model "Orchestrator (Neon)"agy -p "Add input validation to the signup form and run the tests." --model "Orchestrator (Carbon)"

Run agy models to list every model identifier available to your account. Because Orchestrator in the CLI uses a fixed reasoning budget, --effort and /effort don’t apply to it; running /effort while Orchestrator is selected reports that effort isn’t adjustable for it, for example Effort isn't adjustable for Orchestrator (Carbon).

### When to use Orchestrator
Section titled “When to use Orchestrator”

- Orchestrator (recommended default): Most day-to-day development, such as feature work, bug fixes, refactoring, and multi-file debugging, where you want a top-tier planner model (such as Gemini 4 Neon, Gemini 4 Carbon, Gemini 4 Argon, or Claude Opus 5.5) to plan and review the work while a faster executor (such as Gemini 4 Hydrogen) carries out implementation steps.

- Gemini 4 Neon, Gemini 4 Carbon, or Gemini 4 Argon: Work where every intermediate step needs maximum reasoning depth on a single model, such as designing complex distributed systems from scratch, untangling subtle concurrency race conditions, or running multi-repository migrations.

- Gemini 4 Hydrogen: Fast, everyday coding and maintenance tasks where you don’t need a separate planning phase, such as package upgrades, code deduplication, scaffolding boilerplate, writing unit tests for well-defined functions, updating documentation, or generating quick scripts.

Orchestrator keeps a single agent in your conversation and hands off between planning and execution within each turn. To have multiple agents work in parallel or check each other’s work, use subagents, Swarm, Boost, or Teamwork.

## Additional models
Section titled “Additional models”

Antigravity uses other models for various parts of the stack that aren’t customizable:

- Nano Banana 2: Used by the generative image tool when the agent produces a UI mockup, generates images to populate a web page or application, creates system or architecture diagrams, or performs other generative image tasks.
