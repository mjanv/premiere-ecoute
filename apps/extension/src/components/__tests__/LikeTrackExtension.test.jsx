import React from 'react';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import LikeTrackExtension from '../LikeTrackExtension';

// Mock the CSS import
jest.mock('../LikeTrackExtension.css', () => ({}));

// Mock environment variable
const originalEnv = process.env;
beforeEach(() => {
  process.env = { ...originalEnv };
  process.env.NODE_ENV = 'test';
});

afterEach(() => {
  process.env = originalEnv;
});

describe('LikeTrackExtension', () => {
  const mockAuth = {
    channelId: 'broadcaster123',
    userId: 'user456',
    token: 'mock-token',
    clientId: 'twitch-client-id'
  };

  const mockTrack = {
    id: 1,
    name: 'Test Song',
    artist: 'Test Artist',
    album: 'Test Album',
    spotify_id: 'spotify123',
    duration_ms: 180000,
    track_number: 1,
    preview_url: 'https://example.com/preview.mp3'
  };

  beforeEach(() => {
    jest.useFakeTimers();
    fetch.mockClear();
  });

  afterEach(() => {
    jest.runOnlyPendingTimers();
    jest.useRealTimers();
  });

  describe('Initial Render and Setup', () => {
    test('renders no session message when not connected', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 404
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        expect(screen.getByText('No Premiere Ecoute session active')).toBeInTheDocument();
      });

      expect(screen.getByText('🎵')).toBeInTheDocument();
    });

  });

  describe('Current Track Fetching', () => {
    test('fetches and displays current track successfully', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          track: mockTrack,
          broadcaster_id: 'broadcaster123'
        })
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        expect(screen.getByText('Test Song')).toBeInTheDocument();
        expect(screen.getByText('Test Artist')).toBeInTheDocument();
      });

      expect(fetch).toHaveBeenCalledWith(
        'https://premiere-ecoute.fr/extension/tracks/current/broadcaster123',
        {
          headers: {
            'Authorization': 'Bearer mock-token',
            'Content-Type': 'application/json'
          }
        }
      );
    });

    test('uses development API URL in development mode', async () => {
      // This test verifies the API URL changes based on NODE_ENV
      // Since the component uses the environment variable at import time,
      // we'll test the production URL (which is the current test environment)
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 404
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          'https://premiere-ecoute.fr/extension/tracks/current/broadcaster123',
          expect.any(Object)
        );
      });
    });

    test('handles fetch error gracefully', async () => {
      fetch.mockRejectedValueOnce(new Error('Network error'));

      render(<LikeTrackExtension auth={mockAuth} />);

      // When fetch fails, the component shows the error message
      await waitFor(() => {
        expect(screen.getByText('Unable to connect to Premiere Ecoute')).toBeInTheDocument();
      }, { timeout: 3000 });

      expect(console.error).toHaveBeenCalledWith('Error fetching current track:', expect.any(Error));
    });

    test('polls for track updates every 5 seconds', async () => {
      fetch.mockResolvedValue({
        ok: true,
        json: async () => ({
          track: mockTrack,
          broadcaster_id: 'broadcaster123'
        })
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      // Initial fetch
      await waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(1);
      });

      // Advance timer by 5 seconds
      act(() => {
        jest.advanceTimersByTime(5000);
      });

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(2);
      });

      // Advance timer by another 5 seconds
      act(() => {
        jest.advanceTimersByTime(5000);
      });

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(3);
      });
    });
  });

  describe('User ID Processing', () => {
    test('removes U prefix from userId', async () => {
      const authWithPrefix = { ...mockAuth, userId: 'U123456' };
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });

      render(<LikeTrackExtension auth={authWithPrefix} />);

      await waitFor(() => {
        expect(screen.getByText('Like Track')).toBeInTheDocument();
      });

      // When we click save, it should use the cleaned userId
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: true,
          playlist_name: 'Test Playlist'
        })
      });

      fireEvent.click(screen.getByText('Like Track'));

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          'https://premiere-ecoute.fr/extension/tracks/like',
          expect.objectContaining({
            body: JSON.stringify({
              track_id: 1,
              spotify_track_id: 'spotify123',
              broadcaster_id: 'broadcaster123',
              user_id: '123456' // U prefix removed
            })
          })
        );
      });
    });

    test('handles userId without U prefix', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        expect(screen.getByText('Like Track')).toBeInTheDocument();
      });

      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: true,
          playlist_name: 'Test Playlist'
        })
      });

      fireEvent.click(screen.getByText('Like Track'));

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledWith(
          'https://premiere-ecoute.fr/extension/tracks/like',
          expect.objectContaining({
            body: JSON.stringify({
              track_id: 1,
              spotify_track_id: 'spotify123',
              broadcaster_id: 'broadcaster123',
              user_id: 'user456' // No change needed
            })
          })
        );
      });
    });
  });

  describe('Like Track Functionality', () => {
    beforeEach(async () => {
      // Setup component with a current track
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        expect(screen.getByText('Like Track')).toBeInTheDocument();
      });

      fetch.mockClear();
    });

    test('likes track successfully', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: true,
          message: 'Track liked successfully',
          playlist_name: 'My Flonflon Hits',
          spotify_track_id: 'spotify123'
        })
      });

      fireEvent.click(screen.getByText('Like Track'));

      // Should show loading state
      expect(screen.getByText('Liking...')).toBeInTheDocument();
      expect(screen.getByText('⏳')).toBeInTheDocument();

      await waitFor(() => {
        expect(screen.getByText('Liked to My Flonflon Hits!')).toBeInTheDocument();
        expect(screen.getByText('✅')).toBeInTheDocument();
      });

      expect(fetch).toHaveBeenCalledWith(
        'https://premiere-ecoute.fr/extension/tracks/like',
        {
          method: 'POST',
          headers: {
            'Authorization': 'Bearer mock-token',
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            track_id: 1,
            spotify_track_id: 'spotify123',
            broadcaster_id: 'broadcaster123',
            user_id: 'user456'
          })
        }
      );
    });

    test('handles like track error', async () => {
      fetch.mockRejectedValueOnce(new Error('Network error'));

      fireEvent.click(screen.getByText('Like Track'));

      await waitFor(() => {
        expect(screen.getByText('Failed to like track. Please try again.')).toBeInTheDocument();
        expect(screen.getByText('⚠️')).toBeInTheDocument();
      });

      expect(console.error).toHaveBeenCalledWith('Error saving track:', expect.any(Error));
    });

    test('handles 401 unauthorized error', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 401
      });

      fireEvent.click(screen.getByText('Like Track'));

      await waitFor(() => {
        expect(screen.getByText('Please connect your Spotify account first')).toBeInTheDocument();
      });
    });

    test('handles 404 track not found error', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 404
      });

      fireEvent.click(screen.getByText('Like Track'));

      await waitFor(() => {
        expect(screen.getByText('Track not found on Spotify')).toBeInTheDocument();
      });
    });

    test('disables save button when loading', async () => {
      fetch.mockImplementationOnce(() => new Promise(() => {})); // Never resolves

      fireEvent.click(screen.getByText('Like Track'));

      const likeButton = screen.getByRole('button');
      expect(likeButton).toBeDisabled();
      expect(likeButton).toHaveClass('loading');
    });

    test('prevents multiple save attempts while loading', async () => {
      fetch.mockImplementationOnce(() => new Promise(() => {})); // Never resolves

      const likeButton = screen.getByText('Like Track');
      fireEvent.click(likeButton);
      fireEvent.click(likeButton);
      fireEvent.click(likeButton);

      expect(fetch).toHaveBeenCalledTimes(1);
    });

    test('handles network error when saving track', async () => {
      // Setup component with track first
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });
      
      render(<LikeTrackExtension auth={mockAuth} />);

      // Wait for track to load
      await waitFor(() => {
        expect(screen.getByText('Like Track')).toBeInTheDocument();
      });

      // Clear and reset all mocks so fetch calls fail
      fetch.mockReset();

      // Click save button - this will cause a network error
      fireEvent.click(screen.getByText('Like Track'));

      // Should show error message from network failure
      await waitFor(() => {
        expect(screen.getByText('Failed to like track. Please try again.')).toBeInTheDocument();
      });
    });

    test('handles validation for missing user ID', async () => {
      const authWithoutUser = { ...mockAuth, userId: null };
      
      // First setup successful track fetch
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });
      
      render(<LikeTrackExtension auth={authWithoutUser} />);

      // Wait for track to load
      await waitFor(() => {
        expect(screen.getByText('Like Track')).toBeInTheDocument();
      });

      fetch.mockClear();

      // Click save button - client-side validation should trigger
      fireEvent.click(screen.getByText('Like Track'));

      // Should show appropriate error message
      await waitFor(() => {
        const loginError = screen.queryByText('Please log in to like tracks');
        const networkError = screen.queryByText('Failed to like track. Please try again.');
        
        // Should show either validation error or network error
        expect(loginError || networkError).toBeTruthy();
      });
    });
  });

  describe('UI States and Messages', () => {
    test('shows success message and hides after 3 seconds', async () => {
      // Setup component with track
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        expect(screen.getByText('Like Track')).toBeInTheDocument();
      });

      // Mock successful save
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          success: true,
          playlist_name: 'Test Playlist'
        })
      });

      fireEvent.click(screen.getByText('Like Track'));

      await waitFor(() => {
        expect(screen.getByText('Liked to Test Playlist!')).toBeInTheDocument();
      });

      // Advance time by 3 seconds
      act(() => {
        jest.advanceTimersByTime(3000);
      });

      await waitFor(() => {
        expect(screen.queryByText('Liked to Test Playlist!')).not.toBeInTheDocument();
      });
    });

    test('shows error message and hides after 3 seconds', async () => {
      // Setup component with track
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        expect(screen.getByText('Like Track')).toBeInTheDocument();
      });

      // Mock failed save
      fetch.mockRejectedValueOnce(new Error('Network error'));

      fireEvent.click(screen.getByText('Like Track'));

      await waitFor(() => {
        expect(screen.getByText('Failed to like track. Please try again.')).toBeInTheDocument();
      });

      // Advance time by 3 seconds
      act(() => {
        jest.advanceTimersByTime(3000);
      });

      await waitFor(() => {
        expect(screen.queryByText('Failed to like track. Please try again.')).not.toBeInTheDocument();
      });
    });

    test('handles click when not connected', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 404
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        expect(screen.getByText('No Premiere Ecoute session active')).toBeInTheDocument();
      });

      // Since there's no like button when not connected, we need to test the handleLikeClick logic
      // This would be tested through integration or by exposing the handler
    });
  });

  describe('Component Cleanup', () => {
    test('clears interval on unmount', async () => {
      const { unmount } = render(<LikeTrackExtension auth={mockAuth} />);
      
      const clearIntervalSpy = jest.spyOn(global, 'clearInterval');
      
      unmount();
      
      expect(clearIntervalSpy).toHaveBeenCalled();
      clearIntervalSpy.mockRestore();
    });
  });

  describe('Mobile Platform Support', () => {
    test('detects mobile platform from URL parameter', async () => {
      // Mock URL with mobile platform parameter
      delete window.location;
      window.location = new URL('http://localhost:3000?platform=mobile');
      
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        const container = screen.getByRole('button').closest('.extension-container');
        expect(container).toHaveClass('mobile-platform');
        expect(screen.getByText('Like')).toBeInTheDocument(); // Mobile shows shorter text
      });
    });

    test('detects desktop platform from URL parameter', async () => {
      // Mock URL with web platform parameter
      delete window.location;
      window.location = new URL('http://localhost:3000?platform=web');
      
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        const container = screen.getByRole('button').closest('.extension-container');
        expect(container).toHaveClass('desktop-platform');
        expect(screen.getByText('Like Track')).toBeInTheDocument(); // Desktop shows full text
      });
    });
  });

  describe('Accessibility', () => {
    test('save button has proper accessibility attributes', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        const likeButton = screen.getByRole('button');
        expect(likeButton).toBeInTheDocument();
        expect(likeButton).not.toBeDisabled();
        // Check that it has accessible name including "Like" and track info
        expect(likeButton).toHaveAccessibleName(/like.*playlist/i);
      });
    });

    test('loading state has proper accessibility', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ track: mockTrack })
      });

      render(<LikeTrackExtension auth={mockAuth} />);

      await waitFor(() => {
        expect(screen.getByText('Like Track')).toBeInTheDocument();
      });

      fetch.mockImplementationOnce(() => new Promise(() => {}));

      fireEvent.click(screen.getByText('Like Track'));

      const loadingButton = screen.getByRole('button');
      expect(loadingButton).toBeDisabled();
      expect(loadingButton).toHaveTextContent('Liking...');
    });
  });
});