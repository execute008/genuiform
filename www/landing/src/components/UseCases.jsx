// CSS-only animated icons. All keyframes live in styles.css.
const IconPulse = () => <div className="ic-pulse"></div>;
const IconBars = () => (
  <div className="ic-bars">
    <span></span><span></span><span></span><span></span>
  </div>
);
const IconBranch = () => (
  <div className="ic-branch"><i></i><i></i></div>
);

const cards = [
  {
    icon: <IconPulse />,
    tag: '// MEDICAL_INTAKE',
    title: 'Medical intake',
    body: "Escalates when it should. Skips when it can. Constraints make sure the model never asks for what it shouldn't.",
  },
  {
    icon: <IconBars />,
    tag: '// FITNESS_ONBOARDING',
    title: 'Fitness onboarding',
    body: "Meets the athlete where they are. The cardio newbie and the powerlifter don't get the same intake. Already shipping in GymGeist.",
  },
  {
    icon: <IconBranch />,
    tag: '// LEAD_QUAL',
    title: 'Lead qualification',
    body: 'Qualifies fast. Declines gracefully. The right humans book calls. The wrong fit gets a polite, useful exit.',
  },
];

export default function UseCases() {
  return (
    <section className="usecases" id="usecases">
      <div className="container">
        <div className="section-head reveal">
          <div className="eyebrow">Built for</div>
          <h2>Forms that matter.</h2>
          <p className="lead">
            If your form has stakes — safety, money, trust — it should think harder than a Typeform.
          </p>
        </div>

        <div className="uc-grid reveal-stagger">
          {cards.map((c) => (
            <div className="uc-card" key={c.title}>
              <div className="uc-icon">{c.icon}</div>
              <span className="uc-tag">{c.tag}</span>
              <h3>{c.title}</h3>
              <p>{c.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
