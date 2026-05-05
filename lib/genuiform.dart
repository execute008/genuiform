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
