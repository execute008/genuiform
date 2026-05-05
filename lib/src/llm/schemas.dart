// JSON Schema definitions for Vertex AI Gemini responseSchema enforcement.
//
// These schemas are passed verbatim to
// `generationConfig.responseSchema` in the Vertex AI payload (see spec §10.2).
// Vertex AI uses them to constrain the model's output to valid JSON that the
// runtime can parse without guessing.

/// Returns the JSON Schema for [GenerativeStrategy]'s per-turn LLM output.
///
/// The `decision` discriminator tells the runtime which sibling field to read:
/// - `"ask_step"` → read `step`
/// - `"offer_exit"` → read `exit_offer`
/// - `"resolve_branch"` → read `branch_resolution`
/// - `"complete"` → read `outcome`
///
/// `engagement` is always present regardless of decision and feeds the next
/// turn's system prompt so the model can track momentum across the conversation.
///
/// Each property is documented inline below. The schema mirrors spec §10.2
/// verbatim, extended with a full `QuizStepSpec`-compatible `step` object
/// (keys: id, title, description, inputType, choices) matching what
/// `QuizStepSpec.toJson()` will emit once Phase 1 lands.
///
/// Returns a new [Map] instance on each call — safe to mutate if needed.
Map<String, dynamic> generativeStrategyResponseSchema() => {
      'type': 'object',
      'required': ['decision', 'engagement'],
      'properties': {
        /// One of `ask_step | offer_exit | resolve_branch | complete`.
        /// Acts as a discriminator so the runtime knows which sibling field
        /// to read this turn.
        'decision': {
          'type': 'string',
          'enum': ['ask_step', 'offer_exit', 'resolve_branch', 'complete'],
        },

        /// The next question to render. Present when `decision == "ask_step"`.
        /// Shape matches `QuizStepSpec.toJson()` from Phase 1.
        'step': {
          'type': 'object',
          'properties': {
            /// Stable unique ID for this step (e.g. `"step_pain_point"`).
            'id': {'type': 'string'},

            /// Short heading displayed to the user above the input widget.
            'title': {'type': 'string'},

            /// Optional explanatory copy shown beneath the title.
            'description': {'type': 'string'},

            /// Selects the input widget to render. Must be one of the
            /// recognised `QuizInputType` values — the LLM is not allowed
            /// to invent new types.
            'inputType': {
              'type': 'string',
              'enum': [
                'slider',
                'choice',
                'multiChoice',
                'text',
                'number',
                'date',
                'noneJustInformation',
              ],
            },

            /// List of choices for `choice` and `multiChoice` input types.
            /// Each choice has an `id`, `label`, and optional `iconId`.
            'choices': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  /// Stable identifier for this choice, used in answer
                  /// recording.
                  'id': {'type': 'string'},

                  /// Human-readable label displayed on the choice button.
                  'label': {'type': 'string'},

                  /// Optional icon key from the genuiform icon registry.
                  'iconId': {'type': 'string'},
                },
                'required': ['id', 'label'],
              },
            },

            /// For `slider` type: the minimum value.
            'min': {'type': 'number'},

            /// For `slider` type: the maximum value.
            'max': {'type': 'number'},

            /// For `slider` type: the step increment between values.
            'step': {'type': 'number'},

            /// For `slider` type: unit label displayed alongside the value
            /// (e.g. `"kg"`, `"min"`).
            'unit': {'type': 'string'},
          },
          'required': ['id', 'title', 'inputType'],
        },

        /// Branch resolution payload. Present when
        /// `decision == "resolve_branch"`.
        'branch_resolution': {
          'type': 'object',
          'properties': {
            /// The `Branch.id` being resolved.
            'branch_id': {'type': 'string'},

            /// The `BranchOption.id` the model selected.
            'option_id': {'type': 'string'},

            /// Natural-language justification for the chosen option. Useful
            /// for debugging routing decisions during development.
            'rationale': {'type': 'string'},
          },
          'required': ['branch_id', 'option_id'],
        },

        /// A graceful-exit question shown to the user when
        /// `decision == "offer_exit"`. Same shape as `step` — renders using
        /// `noneJustInformation` or a `choice` with accept/decline options.
        'exit_offer': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'title': {'type': 'string'},
            'description': {'type': 'string'},
            'inputType': {
              'type': 'string',
              'enum': [
                'slider',
                'choice',
                'multiChoice',
                'text',
                'number',
                'date',
                'noneJustInformation',
              ],
            },
            'choices': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'id': {'type': 'string'},
                  'label': {'type': 'string'},
                  'iconId': {'type': 'string'},
                },
                'required': ['id', 'label'],
              },
            },
          },
          'required': ['id', 'title', 'inputType'],
        },

        /// Terminal outcome payload. Present when `decision == "complete"`.
        'outcome': {
          'type': 'object',
          'properties': {
            /// The `Outcome.id` the model has determined has been reached.
            'outcome_id': {'type': 'string'},

            /// A brief natural-language summary of what was learned during
            /// the session, surfaced in the `FormResult` for downstream use.
            'summary': {'type': 'string'},
          },
          'required': ['outcome_id'],
        },

        /// The model's read of the user's engagement level this turn.
        /// Always present. Fed back into the next turn's system prompt as
        /// `ENGAGEMENT SIGNAL FROM LAST ANSWER`.
        'engagement': {
          'type': 'string',
          'enum': ['strong', 'weak', 'negative'],
        },
      },
    };
