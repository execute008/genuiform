/// Generative UI Forms for Flutter.
///
/// Public API will be exposed here as phases land.
library;

// ---------------------------------------------------------------------------
// Phase 1 — Models layer
// ---------------------------------------------------------------------------

// Core data types
export 'src/models/num_range.dart' show NumRange;
export 'src/models/field_spec.dart' show FieldSpec, kFieldTypeFromString;
export 'src/models/contract.dart' show Contract;
export 'src/models/posture.dart' show Posture;
export 'src/models/handoff.dart' show Handoff, EscalationHandler;

// Constraints
export 'src/models/constraints.dart'
    show
        Constraint,
        constraintFromJson,
        constraintToJson,
        NeverCollect,
        NeverSkip,
        MaxSteps,
        MinSteps,
        WhitelistChoices,
        EscalateIf,
        StopIf,
        RequireConsent;

// Outcome tree
export 'src/models/outcomes.dart'
    show OutcomeNode, Layer, Branch, Outcome, BranchOption;

// Quiz step types
export 'src/models/quiz_input_type.dart'
    show QuizInputType, quizInputTypeToJson, quizInputTypeFromJson;
export 'src/models/quiz_choice.dart' show QuizChoice;
export 'src/models/quiz_step_spec.dart' show QuizStepSpec;

// Session & engagement
export 'src/models/engagement_signal.dart'
    show EngagementSignal, engagementSignalToJson, engagementSignalFromJson;
export 'src/models/session_status.dart'
    show SessionStatus, sessionStatusToJson, sessionStatusFromJson;
export 'src/models/answer.dart' show Answer;
export 'src/models/session.dart' show Session;

// Results & events
export 'src/models/form_result.dart' show FormResult;
export 'src/models/message.dart' show Message, MessageRole;
export 'src/models/step_event.dart'
    show
        StepEvent,
        StepReady,
        LayerComplete,
        BranchTaken,
        OutcomeReached,
        EscalationFired,
        StreamError;

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------

export 'src/icons/icon_registry.dart' show IconRegistry;

// ---------------------------------------------------------------------------
// Phase 3 — LLM client + Vertex transports + fake
// ---------------------------------------------------------------------------

// LlmClient abstract interface, LlmClientError sealed family.
// Message is now provided by Phase 1's models/message.dart — hide the temp stub.
export 'src/llm/llm_client.dart';

// VertexDirectClient — direct Vertex AI REST transport (dev/server-side only).
export 'src/llm/vertex_direct_client.dart';

// VertexProxyClient — Firebase Function proxy transport (stub; v0.4).
export 'src/llm/vertex_proxy_client.dart';

// FakeLlmClient — scripted test double for use in consumer test suites.
export 'src/llm/fake_llm_client.dart';

// JSON Schema for GenerativeStrategy's per-turn LLM response.
export 'src/llm/schemas.dart';

// ---------------------------------------------------------------------------
// Phase 4 — Runtime primitives
// ---------------------------------------------------------------------------

// ConstraintEnforcer — checks every LLM-emitted step and every user answer
// against the active Constraint list. Exports the EnforcementResult sealed
// family (Allowed, Replaced, Stop, Escalated).
export 'src/runtime/constraint_enforcer.dart'
    show
        ConstraintEnforcer,
        EnforcementResult,
        Allowed,
        Replaced,
        Stop,
        Escalated;

// OutcomeNavigator — walks the OutcomeNode tree, computes the running
// contract from the chosen path, and advances the session through the tree.
export 'src/runtime/outcome_navigator.dart' show OutcomeNavigator;

// EngagementReader — extracts an EngagementSignal from an LLM report or
// from a deterministic heuristic over answer text and history.
export 'src/runtime/engagement_reader.dart' show EngagementReader;

// ---------------------------------------------------------------------------
// Phase 5 — Strategies
// ---------------------------------------------------------------------------

// Abstract strategy contract.
export 'src/strategies/strategy.dart' show Strategy;

// Frozen config object bundling all four primitives + client.
export 'src/strategies/form_config.dart' show FormConfig;

// Prompt assembly helpers (useful for debugging and logging).
export 'src/strategies/prompt_builder.dart'
    show buildGenerativeSystemPrompt, buildGuidedSystemPrompt;

// Generative strategy — every step from the LLM.
export 'src/strategies/generative_strategy.dart' show GenerativeStrategy;

// Guided strategy — LLM picks from a developer-supplied catalog.
export 'src/strategies/guided_strategy.dart' show GuidedStrategy;

// ---------------------------------------------------------------------------
// Phase 6 — Input renderers
// ---------------------------------------------------------------------------

export 'src/widgets/inputs/inputs.dart';

// ---------------------------------------------------------------------------
// Phase 7 — GenuiForm widget + FormController + StepRenderer + StreamingIndicator
// ---------------------------------------------------------------------------

export 'src/widgets/genui_form.dart' show GenuiForm;
export 'src/widgets/form_controller.dart' show FormController;
export 'src/widgets/step_renderer.dart' show StepRenderer;
export 'src/widgets/streaming_indicator.dart' show StreamingIndicator;
