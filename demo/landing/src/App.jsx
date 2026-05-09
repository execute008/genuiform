import { useEffect } from 'react';
import Nav from './components/Nav.jsx';
import Hero from './components/Hero.jsx';
import Problem from './components/Problem.jsx';
import Footer from './components/Footer.jsx';
import FloatDemo from './components/FloatDemo.jsx';
import useReveal from './hooks/useReveal.js';

export default function App() {
  useReveal();

  // Inject Google Fonts at runtime so styles.css stays portable.
  useEffect(() => {
    if (document.getElementById('genuiform-fonts')) return;
    const link = document.createElement('link');
    link.id = 'genuiform-fonts';
    link.rel = 'stylesheet';
    link.href =
      'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Space+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap';
    document.head.appendChild(link);
  }, []);

  return (
    <>
      <Nav />
      <Hero />
      <Problem />
      <Footer />
      <FloatDemo />
    </>
  );
}
