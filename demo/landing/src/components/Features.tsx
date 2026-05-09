import React from 'react';
import './Features.css';

const Features: React.FC = () => {
  const features = [
    {
      icon: '🤖',
      title: 'AI-Powered Conversations',
      description: 'Natural language processing understands context and guides users through complex forms with intelligent responses.'
    },
    {
      icon: '⚡',
      title: 'Lightning Fast',
      description: 'Build forms 10x faster with our declarative DSL. No complex UI code required - just describe what you need.'
    },
    {
      icon: '🎯',
      title: 'Smart Validation',
      description: 'Automatic validation with helpful error messages that actually make sense to your users.'
    },
    {
      icon: '📊',
      title: 'Adaptive Flows',
      description: 'Forms that adapt based on user responses, creating personalized experiences for every interaction.'
    },
    {
      icon: '🔒',
      title: 'Enterprise Ready',
      description: 'Built-in security, compliance features, and scalability for organizations of any size.'
    },
    {
      icon: '🌍',
      title: 'Multi-Language',
      description: 'Automatic translation and localization support for global applications.'
    }
  ];

  return (
    <section id="features" className="features">
      <div className="container">
        <div className="section-header">
          <h2 className="section-title">Why genUIform?</h2>
          <p className="section-subtitle">
            Transform the way you collect data with intelligent, conversational forms
          </p>
        </div>
        
        <div className="features-grid">
          {features.map((feature, index) => (
            <div key={index} className="feature-card">
              <div className="feature-icon">{feature.icon}</div>
              <h3 className="feature-title">{feature.title}</h3>
              <p className="feature-description">{feature.description}</p>
            </div>
          ))}
        </div>

        <div className="features-showcase">
          <div className="showcase-content">
            <h3>See it in action</h3>
            <p>Watch how genUIform transforms a complex registration process into a delightful conversation</p>
            <button className="play-button">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
                <path d="M8 5v14l11-7z"/>
              </svg>
            </button>
          </div>
          <div className="showcase-visual">
            <div className="terminal">
              <div className="terminal-header">
                <span className="terminal-title">genUIform.demo</span>
              </div>
              <div className="terminal-content">
                <div className="terminal-line">
                  <span className="prompt">$</span> genuiform create registration-form
                </div>
                <div className="terminal-line success">
                  ✓ Form created successfully
                </div>
                <div className="terminal-line">
                  <span className="prompt">$</span> genuiform deploy
                </div>
                <div className="terminal-line success">
                  ✓ Deployed to production
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default Features;