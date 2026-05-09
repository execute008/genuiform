import React from 'react';
import './App.css';
import Hero from './components/Hero';
import Features from './components/Features';
import HowItWorks from './components/HowItWorks';
import CodeExample from './components/CodeExample';
import Footer from './components/Footer';

function App() {
  return (
    <div className="App">
      <Hero />
      <Features />
      <HowItWorks />
      <CodeExample />
      <Footer />
    </div>
  );
}

export default App;
