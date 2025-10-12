import React from 'react';
import ReactDOM from 'react-dom/client';
import SaveTrackExtension from './components/SaveTrackExtension';

// Wait for Twitch Extension Helper to be available
const initializeExtension = () => {
  if (window.Twitch && window.Twitch.ext) {
    window.Twitch.ext.onAuthorized((auth) => {
      const root = ReactDOM.createRoot(document.getElementById('twitch-extension-root'));
      root.render(<SaveTrackExtension auth={auth} />);
    });

    // Handle extension context updates
    window.Twitch.ext.onContext((context, delta) => {
      // Handle context changes like theme, language, etc.
      console.log('Extension context updated:', context, delta);
    });
  } else {
    // Retry in case Twitch ext isn't loaded yet
    setTimeout(initializeExtension, 100);
  }
};

initializeExtension();