import React, { useState, useEffect } from 'react';
import './SaveTrackExtension.css';

const PREMIERE_ECOUTE_API = process.env.NODE_ENV === 'development' 
  ? 'http://localhost:4000' 
  : 'https://premiere-ecoute.fr';

const SaveTrackExtension = ({ auth }) => {
  const [currentTrack, setCurrentTrack] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [lastSaved, setLastSaved] = useState(null);
  const [error, setError] = useState(null);
  const [isConnected, setIsConnected] = useState(false);

  // Get broadcaster ID and user ID from auth context
  const broadcasterId = auth.channelId;
  // Remove any "U" prefix from userId if present
  const userId = auth.userId?.startsWith('U') ? auth.userId.slice(1) : auth.userId;
  
  // Debug log the auth context (remove in production)
  useEffect(() => {
    console.log('Extension Auth Context:', {
      channelId: auth.channelId,
      userId: auth.userId,
      token: auth.token ? 'present' : 'missing',
      clientId: auth.clientId
    });
  }, [auth]);

  // Fetch current track from Premiere Ecoute
  const fetchCurrentTrack = async () => {
    try {
      const response = await fetch(
        `${PREMIERE_ECOUTE_API}/extension/tracks/current/${broadcasterId}`,
        {
          headers: {
            'Authorization': `Bearer ${auth.token}`,
            'Content-Type': 'application/json'
          }
        }
      );

      if (response.ok) {
        const data = await response.json();
        setCurrentTrack(data.track);
        setIsConnected(true);
        setError(null);
      } else if (response.status === 404) {
        setCurrentTrack(null);
        setIsConnected(false);
      } else {
        throw new Error('Failed to fetch current track');
      }
    } catch (err) {
      console.error('Error fetching current track:', err);
      setError('Unable to connect to Premiere Ecoute');
      setIsConnected(false);
    }
  };

  // Save current track to user's Spotify playlist
  const saveTrack = async () => {
    if (!currentTrack || isLoading) return;

    // Ensure we have the required IDs
    if (!broadcasterId) {
      setError('Missing broadcaster information');
      return;
    }
    
    if (!userId) {
      setError('Please log in to save tracks');
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const requestPayload = {
        track_id: currentTrack.id,
        spotify_track_id: currentTrack.spotify_id,
        broadcaster_id: broadcasterId,
        user_id: userId
      };
      
      // Debug log the request (remove in production)
      console.log('Saving track with payload:', requestPayload);
      
      const response = await fetch(`${PREMIERE_ECOUTE_API}/extension/tracks/save`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${auth.token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestPayload)
      });

      if (response.ok) {
        const data = await response.json();
        setLastSaved({
          track: currentTrack,
          timestamp: Date.now(),
          playlist: data.playlist_name || 'Premiere Ecoute Saved Tracks'
        });
        
        // Show success feedback for 3 seconds
        setTimeout(() => setLastSaved(null), 3000);
      } else if (response.status === 401) {
        setError('Please connect your Spotify account first');
      } else if (response.status === 404) {
        setError('Track not found on Spotify');
      } else {
        throw new Error('Failed to save track');
      }
    } catch (err) {
      console.error('Error saving track:', err);
      setError('Failed to save track. Please try again.');
      setTimeout(() => setError(null), 3000);
    } finally {
      setIsLoading(false);
    }
  };

  // Poll for current track updates
  useEffect(() => {
    fetchCurrentTrack();
    
    const interval = setInterval(fetchCurrentTrack, 5000); // Poll every 5 seconds
    return () => clearInterval(interval);
  }, [broadcasterId]);

  // Handle user interaction
  const handleSaveClick = () => {
    if (!isConnected) {
      setError('No active listening session detected');
      setTimeout(() => setError(null), 3000);
      return;
    }
    saveTrack();
  };

  if (!isConnected && !error) {
    return (
      <div className="extension-container">
        <div className="no-session">
          <div className="icon">🎵</div>
          <p>No Premiere Ecoute session active</p>
        </div>
      </div>
    );
  }

  return (
    <div className="extension-container">
      {error && (
        <div className="error-message">
          <span className="error-icon">⚠️</span>
          {error}
        </div>
      )}
      
      {lastSaved && (
        <div className="success-message">
          <span className="success-icon">✅</span>
          Saved to {lastSaved.playlist}!
        </div>
      )}
      
      {currentTrack && (
        <div className="track-info">
          <div className="track-details">
            <div className="track-title">{currentTrack.name}</div>
            <div className="track-artist">{currentTrack.artist}</div>
          </div>
          
          <button 
            className={`save-button ${isLoading ? 'loading' : ''}`}
            onClick={handleSaveClick}
            disabled={isLoading}
          >
            {isLoading ? (
              <span className="loading-spinner">⏳</span>
            ) : (
              <span className="save-icon">💾</span>
            )}
            {isLoading ? 'Saving...' : 'Save Track'}
          </button>
        </div>
      )}
    </div>
  );
};

export default SaveTrackExtension;