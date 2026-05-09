import Brand from './Brand.jsx';

export default function Footer() {
  return (
    <footer>
      <div className="footer-inner">
        <div className="footer-left">
          <Brand className="" />
          <div className="footer-tag">Forms that read the room.</div>
          <div className="footer-meta">
            Built for the Generative UI Global Hackathon · Vienna · May 2026
          </div>
        </div>
        <div className="footer-right">
          <a href="https://github.com">GitHub →</a>
          <a href="#install">pub.dev →</a>
          <a href="#">Docs →</a>
          <a href="#">License: MIT</a>
        </div>
      </div>
    </footer>
  );
}
