import { useEffect, useState } from 'react';

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
        <a href="#" className="nav-logo">genUIform</a>
        <span className="badge"><span className="dot"></span>open source</span>
      </div>
      <div className="nav-right">
      </div>
    </nav>
  );
}
