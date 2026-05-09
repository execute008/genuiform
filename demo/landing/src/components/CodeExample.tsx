import React, { useState } from 'react';
import './CodeExample.css';

const CodeExample: React.FC = () => {
  const [activeTab, setActiveTab] = useState('dsl');

  const examples = {
    dsl: {
      title: 'DSL Definition',
      code: `contract {
  text firstName "What's your first name?"
  text lastName "And your last name?"
  email email "Email address" {
    validate: email
    required: true
  }
  select experience "Years of experience" {
    options: ["0-2", "3-5", "5-10", "10+"]
  }
  multiselect skills "Select your skills" {
    options: ["React", "TypeScript", "Node.js", "Python"]
    min: 1
    max: 4
  }
}

constraints {
  max_messages: 10
  timeout: 300
  allow_restart: true
}

posture {
  tone: professional_friendly
  pace: moderate
  verbosity: concise
}

outcomes {
  complete -> submit_application
  incomplete -> save_draft
  error -> show_support
}`
    },
    react: {
      title: 'React Integration',
      code: `import { GenuiForm } from '@genuiform/react';

function ApplicationForm() {
  const handleComplete = (data) => {
    console.log('Form completed:', data);
  };

  return (
    <GenuiForm
      contract={contract}
      constraints={constraints}
      posture={posture}
      outcomes={outcomes}
      onComplete={handleComplete}
    />
  );
}`
    },
    api: {
      title: 'API Response',
      code: `{
  "session": {
    "id": "sess_abc123",
    "status": "active",
    "progress": 0.6
  },
  "message": {
    "role": "assistant",
    "content": "Great! Now, could you tell me about your experience level?",
    "suggestions": ["0-2 years", "3-5 years", "5-10 years"]
  },
  "collected": {
    "firstName": "John",
    "lastName": "Doe",
    "email": "john@example.com"
  }
}`
    }
  };

  return (
    <section className="code-example">
      <div className="container">
        <div className="section-header">
          <h2 className="section-title">See the Code</h2>
          <p className="section-subtitle">
            Clean, declarative, and powerful
          </p>
        </div>

        <div className="code-tabs">
          <div className="tabs-header">
            {Object.keys(examples).map(key => (
              <button
                key={key}
                className={`tab ${activeTab === key ? 'active' : ''}`}
                onClick={() => setActiveTab(key)}
              >
                {examples[key as keyof typeof examples].title}
              </button>
            ))}
          </div>
          <div className="tabs-content">
            <pre className="code-block">
              <code>{examples[activeTab as keyof typeof examples].code}</code>
            </pre>
          </div>
        </div>

        <div className="integration-section">
          <h3>Works with your favorite tools</h3>
          <div className="integration-logos">
            <div className="integration-logo">React</div>
            <div className="integration-logo">Vue</div>
            <div className="integration-logo">Angular</div>
            <div className="integration-logo">Next.js</div>
            <div className="integration-logo">TypeScript</div>
            <div className="integration-logo">Node.js</div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default CodeExample;