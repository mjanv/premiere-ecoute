import React, { useState, useEffect } from 'react';
import './LikeTrackExtension.css';

const PREMIERE_ECOUTE_API = process.env.NODE_ENV === 'development' 
  ? 'http://localhost:4000' 
  : 'https://premiere-ecoute.fr';

const LikeTrackExtension = ({ auth }) => {
  const [currentTrack, setCurrentTrack] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [lastLiked, setLastLiked] = useState(null);
  const [error, setError] = useState(null);
  const [isConnected, setIsConnected] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  // Get broadcaster ID and user ID from auth context
  const broadcasterId = auth.channelId;
  // Remove any "U" prefix from userId if present
  const userId = auth.userId?.startsWith('U') ? auth.userId.slice(1) : auth.userId;

  // Detect platform based on Twitch's official query parameters
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const platformParam = urlParams.get('platform');
    
    // Use only Twitch's official platform parameter
    setIsMobile(platformParam === 'mobile');
  }, []);

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

  // Like current track to user's Spotify playlist
  const likeTrack = async () => {
    if (!currentTrack || isLoading) return;

    // Ensure we have the required IDs
    if (!broadcasterId) {
      setError('Missing broadcaster information');
      return;
    }
    
    if (!userId) {
      setError('Please log in to like tracks');
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
      
      const response = await fetch(`${PREMIERE_ECOUTE_API}/extension/tracks/like`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${auth.token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestPayload)
      });

      if (response.ok) {
        const data = await response.json();
        setLastLiked({
          track: currentTrack,
          timestamp: Date.now(),
          playlist: data.playlist_name || 'Premiere Ecoute Liked Tracks'
        });
        
        // Show success feedback for 3 seconds
        setTimeout(() => setLastLiked(null), 3000);
      } else if (response.status === 401) {
        setError('Please connect your Spotify account first');
      } else if (response.status === 404) {
        setError('Track not found on Spotify');
      } else {
        throw new Error('Failed to like track');
      }
    } catch (err) {
      console.error('Error saving track:', err);
      setError('Failed to like track. Please try again.');
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
  const handleLikeClick = () => {
    if (!isConnected) {
      setError('No active listening session detected');
      setTimeout(() => setError(null), 3000);
      return;
    }
    likeTrack();
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
    <div className={`extension-container ${isMobile ? 'mobile-platform' : 'desktop-platform'}`}>
      {error && (
        <div className="error-message">
          <span className="error-icon">⚠️</span>
          {error}
        </div>
      )}
      
      {lastLiked && (
        <div className="success-message">
          <span className="success-icon">✅</span>
          Liked to {lastLiked.playlist}!
        </div>
      )}
      
      {currentTrack && (
        <div className="track-info">
          <div className="track-details">
            <div className="track-title">{currentTrack.name}</div>
            <div className="track-artist">{currentTrack.artist}</div>
          </div>
          
          <button 
            className={`like-button ${isLoading ? 'loading' : ''} ${isMobile ? 'mobile-button' : ''}`}
            onClick={handleLikeClick}
            disabled={isLoading}
            // Add mobile-specific attributes
            aria-label={isLoading ? 'Liking track to playlist...' : `Like ${currentTrack.name} to playlist`}
            {...(isMobile && {
              onTouchStart: (e) => {
                // Add slight haptic-like feedback for mobile
                e.currentTarget.style.transform = 'scale(0.98)';
              },
              onTouchEnd: (e) => {
                setTimeout(() => {
                  if (e.currentTarget) {
                    e.currentTarget.style.transform = '';
                  }
                }, 150);
              }
            })}
          >
            {isLoading ? (
              <span className="loading-spinner">⏳</span>
            ) : (
              <span className="like-icon">❤️</span>
            )}
            {isLoading 
              ? (isMobile ? 'Liking...' : 'Liking...') 
              : (isMobile ? 'Like' : 'Like Track')
            }
          </button>
        </div>
      )}
    </div>
  );
};

export default LikeTrackExtension;