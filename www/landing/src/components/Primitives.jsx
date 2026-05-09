// Each card has a label/name/desc and a syntax-highlighted Dart snippet
// rendered as styled <span>s. JSX makes the highlighting trivial — no lib needed.

function Contract() {
  return (
    <pre>
{'final '}<span className="tok-fn">contract</span>{' = '}<span className="tok-type">Contract</span>{`(
  fields: [
    `}<span className="tok-type">FieldSpec</span>{`(
      id: `}<span className="tok-str">'symptom_summary'</span>{`,
      type: `}<span className="tok-type">FieldType</span>{`.text,
      required: `}<span className="tok-key">true</span>{`,
    ),
    `}<span className="tok-type">FieldSpec</span>{`(
      id: `}<span className="tok-str">'severity'</span>{`,
      type: `}<span className="tok-type">FieldType</span>{`.scale,
      range: (`}<span className="tok-num">1</span>{', '}<span className="tok-num">10</span>{`),
    ),
    `}<span className="tok-type">FieldSpec</span>{`(
      id: `}<span className="tok-str">'consent_to_share'</span>{`,
      type: `}<span className="tok-type">FieldType</span>{`.bool,
      required: `}<span className="tok-key">true</span>{`,
    ),
  ],
);`}
    </pre>
  );
}

function Constraints() {
  return (
    <pre>
{'final '}<span className="tok-fn">constraints</span>{' = '}<span className="tok-type">Constraints</span>{`(
  neverCollect: [
    `}<span className="tok-str">'ssn'</span>{`,
    `}<span className="tok-str">'payment_card'</span>{`,
  ],
  escalateIf: [
    `}<span className="tok-type">Trigger</span>{'.mentions('}<span className="tok-str">'self-harm'</span>{`),
    `}<span className="tok-type">Trigger</span>{'.severity('}<span className="tok-num">8</span>{', '}<span className="tok-num">10</span>{`),
  ],
  maxSteps: `}<span className="tok-num">12</span>{`,
  `}<span className="tok-com">// model gets these as hard rules</span>{`
  `}<span className="tok-com">// — never as suggestions.</span>{`
);`}
    </pre>
  );
}

function Posture() {
  return (
    <pre>
{'final '}<span className="tok-fn">posture</span>{' = '}<span className="tok-type">Posture</span>{`(
  tone: `}<span className="tok-type">Tone</span>{`.reassuring,
  persistence: `}<span className="tok-num">0.3</span>{`,   `}<span className="tok-com">{'// don\'t push'}</span>{`
  pacing: `}<span className="tok-type">Pacing</span>{`.adaptive,
  brevity: `}<span className="tok-num">0.8</span>{`,       `}<span className="tok-com">// keep it tight</span>{`
  fallbackToHuman: `}<span className="tok-key">true</span>{`,
  `}<span className="tok-com">// reads engagement signals</span>{`
  `}<span className="tok-com">{'// → adjusts in flight'}</span>{`
);`}
    </pre>
  );
}

function Outcomes() {
  return (
    <pre>
{'final '}<span className="tok-fn">outcomes</span>{' = '}<span className="tok-type">Outcomes</span>{`(
  branches: [
    `}<span className="tok-type">Branch</span>{'('}<span className="tok-str">'intake_complete'</span>{`,
      onLand: () => `}<span className="tok-fn">notifyClinician</span>{`()),
    `}<span className="tok-type">Branch</span>{'('}<span className="tok-str">'escalate_clinician'</span>{`,
      layer: `}<span className="tok-type">Layer</span>{`.urgent),
    `}<span className="tok-type">Branch</span>{'('}<span className="tok-str">'consent_revoked'</span>{`,
      layer: `}<span className="tok-type">Layer</span>{`.gracefulExit),
  ],
  `}<span className="tok-com">// no branch = no exit.</span>{`
);`}
    </pre>
  );
}

const cards = [
  { n: 1, label: 'CONTRACT', name: 'What to collect', desc: 'A typed list of fields the form must return. The shape is fixed. The how is generative.', code: <Contract /> },
  { n: 2, label: 'CONSTRAINTS', name: 'What must never happen', desc: "Hard rails the model can't cross. Sensitive fields, mandatory escalations, hard caps.", code: <Constraints /> },
  { n: 3, label: 'POSTURE', name: 'How it should feel', desc: 'Tone, persistence, pacing. The form that knows when to push and when to back off.', code: <Posture /> },
  { n: 4, label: 'OUTCOMES', name: 'Where it can land', desc: 'A finite set of terminals. The form must end somewhere you\u2019ve named.', code: <Outcomes /> },
];

export default function Primitives() {
  return (
    <section className="primitives" id="primitives">
      <div className="container">
        <div className="section-head reveal">
          <div className="eyebrow">Four primitives</div>
          <h2>Generative inside.<br />Predictable outside.</h2>
          <p className="lead">
            You configure four things. The model fills in everything else — phrasing, ordering, branching, follow-ups. The contract is yours. The conversation is theirs.
          </p>
        </div>

        <div className="prim-grid reveal-stagger">
          {cards.map((c) => (
            <div className="prim-card" key={c.label}>
              <div className="prim-head">
                <div className="prim-label"><span className="num">{c.n}</span> {c.label}</div>
                <div className="prim-name">{c.name}</div>
                <div className="prim-desc">{c.desc}</div>
              </div>
              <div className="code">{c.code}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
