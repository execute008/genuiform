import Brand from './Brand.jsx';

export default function Workbench() {
  return (
    <div className="workbench-wrap reveal">
      <div className="workbench">
        <div className="wb-titlebar">
          <div className="wb-dots">
            <span></span><span></span><span></span>
          </div>
          <div className="wb-url">workbench.genuiform.draht.dev</div>
        </div>
        <div className="wb-topbar">
          <div className="wb-logo"></div>
          <div className="wb-title"><Brand /> workbench</div>
          <div className="wb-project">Project: untitled · tdl/v3</div>
          <div className="wb-topbar-spacer"></div>
          <span className="wb-chip">⌘ Add API Key</span>
          <span className="wb-chip">⚑ Constraints</span>
          <span className="wb-chip">≡ Tokens</span>
          <span
            className="wb-chip"
            style={{ background: 'var(--primary-container)', color: 'var(--primary)', borderColor: 'transparent' }}
          >
            ↗ Share
          </span>
        </div>

        <div className="wb-body">
          {/* Left: chat */}
          <div className="wb-left">
            <div className="wb-prompt-bar">
              PROMPT
              <span className="pill">gemini-1.5-pro</span>
              <div className="spacer"></div>
              <span className="icon">↻</span>
              <span className="icon">+</span>
            </div>
            <div className="wb-msgs">
              <div className="wb-msg">
                <div className="wb-avatar you">YO</div>
                <div className="wb-msg-body">
                  <div className="wb-msg-name">You</div>
                  <div className="wb-bubble you">
                    I need a medical intake form for a clinic. Reassuring tone. Cap at 12 steps. Escalate if symptoms suggest self-harm.
                  </div>
                </div>
              </div>
              <div className="wb-msg">
                <div className="wb-avatar ai">✦</div>
                <div className="wb-msg-body">
                  <div className="wb-msg-name">Gemini</div>
                  <div className="wb-bubble ai">
                    Here's a draft for Medical intake. I picked a reassuring posture and routed all inputs through tokens in tdl/v3. The form will branch to one of:{' '}
                    <span style={{ color: 'var(--primary)' }}>intake_complete</span>,{' '}
                    <span style={{ color: 'var(--tertiary)' }}>escalate_clinician</span>,{' '}
                    <span style={{ color: 'var(--warning)' }}>consent_revoked</span>.
                  </div>
                  <div className="wb-suggestions">
                    <div className="wb-sugg">Make consent more prominent</div>
                    <div className="wb-sugg">Add an escalation for self-harm mentions</div>
                    <div className="wb-sugg">Cap at 12 steps</div>
                  </div>
                </div>
              </div>
            </div>
            <div className="wb-input">
              <input type="text" placeholder='Describe the form you want — e.g. "a 3-step onboarding…"' readOnly />
              <span>📎</span>
              <span>🎙</span>
              <span className="send">↑</span>
            </div>
          </div>

          {/* Right: preview */}
          <div className="wb-right">
            <div className="wb-preview-bar">
              <div className="wb-preview-title">Medical intake</div>
              <div className="wb-preview-spacer"></div>
              <div className="wb-debug">
                Debug <span className="wb-toggle"></span>
              </div>
              <span className="wb-run">▶ Run</span>
            </div>
            <div className="wb-stage">
              <div className="wb-form-card">
                <div className="wb-form-head">
                  <div className="wb-form-avatar">D</div>
                  <div>
                    <div className="wb-form-greeting">Hi, Dr.</div>
                    <div className="wb-form-name">Medical intake</div>
                  </div>
                  <div className="wb-form-x">×</div>
                </div>
                <div className="wb-form-progress"><div></div></div>
                <div className="wb-form-q">What's going on today?</div>
                <div className="wb-form-help">A short description is enough — your clinician will follow up.</div>
                <div className="wb-form-input">Type your answer…</div>
                <div className="wb-form-actions">
                  <span className="wb-form-cta">→ Continue</span>
                </div>
              </div>
            </div>
            <div className="wb-statusbar">
              <div>
                <span className="wb-stat-label">STEP</span>
                <span className="wb-stat-val">step 1/6</span>
              </div>
              <div>
                <span className="wb-stat-label">ENGAGEMENT</span>
                <span className="wb-stat-val success">strong</span>
              </div>
              <div>
                <span className="wb-stat-label">PATH</span>
                <span className="wb-stat-val">in_progress</span>
              </div>
              <div className="wb-tdl">tdl/v3 · reassuring</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
