import { useState } from 'react';

const COMMAND = 'flutter pub add genuiform';

export default function Install() {
  const [copied, setCopied] = useState(false);
  const [label, setLabel] = useState('Copy');

  const onCopy = async () => {
    try {
      await navigator.clipboard.writeText(COMMAND);
      setCopied(true);
      setLabel('Copied!');
      setTimeout(() => {
        setCopied(false);
        setLabel('Copy');
      }, 1800);
    } catch {
      setLabel('Press ⌘C');
    }
  };

  return (
    <section className="install" id="install">
      <div className="container">
        <div className="install-head reveal">
          <div className="eyebrow">Install</div>
          <h2>One line. Then ship.</h2>
        </div>
        <div className="install-box reveal">
          <span className="prompt">$</span>
          <code>flutter pub add <span className="pkg">genuiform</span></code>
          <button
            className={`copy-btn${copied ? ' copied' : ''}`}
            aria-label="Copy install command"
            onClick={onCopy}
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
              <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
            </svg>
            <span>{label}</span>
          </button>
        </div>
      </div>
    </section>
  );
}
