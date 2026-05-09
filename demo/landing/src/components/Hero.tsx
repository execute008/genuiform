import React from 'react';
import './Hero.css';

const Hero: React.FC = () => {
  return (
    <section className="hero">
      <nav className="navbar">
        <div className="container">
          <div className="nav-wrapper">
            <div className="logo">
              <span className="logo-icon">G</span>
              <span className="logo-text">genUIform</span>
            </div>
            <div className="nav-links">
              <a href="#features">Features</a>
              <a href="#how-it-works">How it Works</a>
              <a href="#docs">Documentation</a>
              <a href="https://github.com" className="github-link">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 0C5.37 0 0 5.37 0 12c0 5.3 3.43 9.8 8.2 11.38.6.11.82-.26.82-.58 0-.29-.01-1.05-.02-2.06-3.34.72-4.04-1.61-4.04-1.61-.55-1.39-1.34-1.76-1.34-1.76-1.09-.75.08-.73.08-.73 1.21.08 1.85 1.24 1.85 1.24 1.07 1.83 2.81 1.3 3.5.99.11-.78.42-1.3.76-1.6-2.67-.3-5.47-1.33-5.47-5.93 0-1.31.47-2.38 1.24-3.22-.13-.3-.54-1.52.12-3.18 0 0 1.01-.32 3.3 1.23.96-.27 1.98-.4 3-.4 1.02 0 2.04.13 3 .4 2.29-1.55 3.3-1.23 3.3-1.23.66 1.66.25 2.88.12 3.18.77.84 1.24 1.91 1.24 3.22 0 4.61-2.81 5.63-5.48 5.93.43.37.82 1.1.82 2.22 0 1.6-.01 2.89-.01 3.28 0 .32.22.7.83.58C20.57 21.8 24 17.3 24 12c0-6.63-5.37-12-12-12z"/>
                </svg>
                GitHub
              </a>
            </div>
            <button className="mobile-menu">
              <span></span>
              <span></span>
              <span></span>
            </button>
          </div>
        </div>
      </nav>

      <div className="hero-content">
        <div className="container">
          <div className="hero-main">
            <h1 className="hero-title">
              Build conversational forms
              <span className="gradient-text"> powered by AI</span>
            </h1>
            <p className="hero-subtitle">
              Transform complex data collection into natural conversations. 
              genUIform creates intelligent, adaptive forms that understand context 
              and guide users through personalized experiences.
            </p>
            <div className="hero-actions">
              <a href="#demo" className="btn btn-primary">
                Try Demo
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                  <path d="M5 12h14M12 5l7 7-7 7" strokeWidth="2" strokeLinecap="round"/>
                </svg>
              </a>
              <a href="#docs" className="btn btn-secondary">
                View Documentation
              </a>
            </div>
            <div className="hero-stats">
              <div className="stat">
                <span className="stat-value">10x</span>
                <span className="stat-label">Faster Development</span>
              </div>
              <div className="stat">
                <span className="stat-value">85%</span>
                <span className="stat-label">Higher Completion</span>
              </div>
              <div className="stat">
                <span className="stat-value">Zero</span>
                <span className="stat-label">Code Required</span>
              </div>
            </div>
          </div>
          <div className="hero-visual">
            <div className="code-preview">
              <div className="code-header">
                <span className="dot red"></span>
                <span className="dot yellow"></span>
                <span className="dot green"></span>
              </div>
              <pre className="code-content">
{`contract {
  text name "What's your name?"
  email email "Email address"
  select role "Your role" {
    options: ["Developer", "Designer", "PM"]
  }
}

posture {
  tone: friendly
  pace: relaxed
}`}
              </pre>
            </div>
            <div className="chat-preview">
              <div className="chat-message bot">
                <div className="avatar">🤖</div>
                <div className="message">Hi! Let's get you set up. What's your name?</div>
              </div>
              <div className="chat-message user">
                <div className="message">John Smith</div>
                <div className="avatar">👤</div>
              </div>
              <div className="chat-message bot">
                <div className="avatar">🤖</div>
                <div className="message">Nice to meet you, John! What's the best email to reach you at?</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default Hero;