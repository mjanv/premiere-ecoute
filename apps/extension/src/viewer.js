import React from 'react';
import ReactDOM from 'react-dom/client';
import LikeTrackExtension from './components/LikeTrackExtension';

// Wait for Twitch Extension Helper to be available
const initializeExtension = () => {
  if (window.Twitch && window.Twitch.ext) {
    let extensionContext = {};
    
    // Handle extension context updates
    window.Twitch.ext.onContext((context, delta) => {
      extensionContext = { ...extensionContext, ...context };
    });

    window.Twitch.ext.onAuthorized((auth) => {
      const root = ReactDOM.createRoot(document.getElementById('twitch-extension-root'));
      
      // Pass both auth and context to the component
      const enhancedAuth = {
        ...auth,
        context: extensionContext
      };
      
      root.render(<LikeTrackExtension auth={enhancedAuth} />);
    });

    // Set up mobile viewport optimizations
    const setupMobileViewport = () => {
      const urlParams = new URLSearchParams(window.location.search);
      const isMobilePlatform = urlParams.get('platform') === 'mobile';
      
      if (isMobilePlatform) {
        // Add mobile-specific viewport and document settings
        document.body.style.touchAction = 'manipulation';
        document.body.style.userSelect = 'none';
        document.body.style.webkitUserSelect = 'none';
        document.body.style.webkitTouchCallout = 'none';
        
        // Prevent zoom on double tap
        let lastTouchEnd = 0;
        document.addEventListener('touchend', (event) => {
          const now = (new Date()).getTime();
          if (now - lastTouchEnd <= 300) {
            event.preventDefault();
          }
          lastTouchEnd = now;
        }, false);
        
      }
    };
    
    setupMobileViewport();
  } else {
    // Retry in case Twitch ext isn't loaded yet
    setTimeout(initializeExtension, 100);
  }
};

initializeExtension();