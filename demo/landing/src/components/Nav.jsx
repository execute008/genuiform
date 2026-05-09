import { useEffect, useState } from 'react';
import Brand from './Brand.jsx';

export default function Nav() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <nav className={`nav${scrolled ? ' scrolled' : ''}`}>
      <div className="nav-left">
        <a href="#" className="nav-logo"><Brand /></a>
        <span className="badge"><span className="dot"></span>v0.3 · open source</span>
      </div>
      <div className="nav-right">
        <a href="#primitives">Primitives</a>
        <a href="#demo">Demo</a>
        <a href="#install">Install</a>
        <a href="https://github.com" className="btn btn-primary">GitHub →</a>
      </div>
    </nav>
  );
}
