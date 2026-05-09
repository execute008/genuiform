import React from 'react';
import './HowItWorks.css';

const HowItWorks: React.FC = () => {
  const steps = [
    {
      number: '01',
      title: 'Define Your Contract',
      description: 'Describe what data you need using our simple DSL',
      code: `contract {
  text name "Full name"
  email email "Email"
  select plan "Choose plan"
}`
    },
    {
      number: '02',
      title: 'Set the Tone',
      description: 'Configure how your form should interact with users',
      code: `posture {
  tone: friendly
  pace: relaxed
  style: conversational
}`
    },
    {
      number: '03',
      title: 'Deploy Instantly',
      description: 'Your intelligent form is ready to use immediately',
      code: `outcomes {
  complete -> "Thank you!"
  incomplete -> retry
}`
    }
  ];

  return (
    <section id="how-it-works" className="how-it-works">
      <div className="container">
        <div className="section-header">
          <h2 className="section-title">How It Works</h2>
          <p className="section-subtitle">
            Get started in minutes with our intuitive DSL
          </p>
        </div>

        <div className="steps-container">
          {steps.map((step, index) => (
            <div key={index} className="step">
              <div className="step-number">{step.number}</div>
              <div className="step-content">
                <h3 className="step-title">{step.title}</h3>
                <p className="step-description">{step.description}</p>
                <div className="step-code">
                  <pre>{step.code}</pre>
                </div>
              </div>
              {index < steps.length - 1 && <div className="step-arrow">→</div>}
            </div>
          ))}
        </div>

        <div className="cta-section">
          <h3>Ready to revolutionize your forms?</h3>
          <p>Join thousands of developers building better user experiences</p>
          <div className="cta-buttons">
            <a href="#" className="btn btn-primary">Start Building</a>
            <a href="#" className="btn btn-outline">View Examples</a>
          </div>
        </div>
      </div>
    </section>
  );
};

export default HowItWorks;