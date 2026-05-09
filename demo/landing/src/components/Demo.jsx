function Persona({ tag, name, count, steps }) {
  return (
    <div className="persona">
      <div className="persona-head">
        <div>
          <div className="persona-tag">{tag}</div>
          <div className="persona-name">{name}</div>
        </div>
        <div className="persona-stat">
          <div className="num">{count}</div>
          <div className="label">QUESTIONS</div>
        </div>
      </div>
      <div className="flow">
        {steps.map((s, i) => (
          <div className={`flow-step ${s.cls || ''}`.trim()} key={i}>
            <span className="step-num">{s.n}</span> {s.text}
          </div>
        ))}
      </div>
    </div>
  );
}

const engaged = {
  tag: 'PERSONA · ENGAGED',
  name: 'CTO, ready to buy',
  count: 4,
  steps: [
    { n: '01', text: 'What are you trying to ship?', cls: 'active' },
    { n: '02', text: 'Team size + stack?', cls: 'active' },
    { n: '03', text: 'Timeline pressure?', cls: 'active' },
    { n: '04', text: 'Budget envelope?', cls: 'active' },
    { n: '→', text: 'Books a 30-min call · branch:qualified_lead', cls: 'book' },
  ],
};

const tired = {
  tag: 'PERSONA · TIRED',
  name: 'Founder, 11pm Tuesday',
  count: 2,
  steps: [
    { n: '01', text: 'What are you trying to ship?', cls: 'active' },
    { n: '02', text: 'Team size + stack?', cls: 'skip' },
    { n: '02', text: 'Want a written proposal instead?', cls: 'active' },
    { n: '03', text: 'Timeline pressure?', cls: 'skip' },
    { n: '04', text: 'Budget envelope?', cls: 'skip' },
    { n: '→', text: 'Sends proposal by email · branch:async_followup', cls: 'exit' },
  ],
};

export default function Demo() {
  return (
    <section className="demo" id="demo">
      <div className="container">
        <div className="section-head reveal">
          <div className="eyebrow">Same config. Different humans.</div>
          <h2>Watch it adapt.</h2>
          <p className="lead">
            Two users. One form. Identical config. The library reads engagement, adjusts depth, and lands each one where they want to land.
          </p>
        </div>

        <div className="demo-grid reveal-stagger">
          <Persona {...engaged} />
          <Persona {...tired} />
        </div>
        <div className="demo-caption reveal">
          Same config. Same form. Different humans. <strong>Watch it adapt.</strong>
        </div>
      </div>
    </section>
  );
}
