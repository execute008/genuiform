const cards = [
  {
    num: '// 01 — Redundancy',
    title: 'Asks the same questions every time.',
    body: 'Treats returning users like strangers. Your most loyal customers fill out their email for the eleventh time and quietly resent you for it.',
  },
  {
    num: '// 02 — Wasted depth',
    title: '15 questions for the guy who knew in 3.',
    body: 'Same flow for everyone. The decisive customer abandons. The unsure one is under-served. You optimize for neither.',
  },
  {
    num: '// 03 — Dead-end framing',
    title: 'Written once, for nobody.',
    body: "Never adapts to what you've already learned. The copy you wrote in March still asks November's customer questions you've answered already.",
  },
];

export default function Problem() {
  return (
    <section className="problem" id="problem">
      <div className="container">
        <div className="section-head reveal">
          <div className="eyebrow">The problem</div>
          <h2>Static forms have three failure modes.</h2>
          <p className="lead">
            Every multi-step form you've built is broken in at least one of these ways. Most are broken in all three.
          </p>
        </div>
        <div className="problem-grid reveal-stagger">
          {cards.map((c) => (
            <div className="problem-card" key={c.num}>
              <div className="marker"></div>
              <div className="problem-num">{c.num}</div>
              <h3 className="problem-title">{c.title}</h3>
              <p>{c.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
