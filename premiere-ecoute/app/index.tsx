import { Text, View, StyleSheet, TouchableOpacity, SafeAreaView, ScrollView, Platform } from "react-native";
import { StatusBar } from "expo-status-bar";
import { useEffect, useState } from "react";
import { Socket } from "phoenix";
import Constants from 'expo-constants';

interface ListeningSession {
  id: string;
  title: string;
  host: string;
  currentTrack?: string;
  artist?: string;
  participantCount: number;
  isActive: boolean;
}

interface CurrentTrack {
  id: string;
  title: string;
  artist: string;
  album?: string;
  duration?: number;
  position?: number;
}

interface Vote {
  trackId: string;
  rating: number; // 1-5 stars
}

export default function Index() {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [channel, setChannel] = useState<any>(null);
  const [connectionStatus, setConnectionStatus] = useState<'disconnected' | 'connecting' | 'connected'>('disconnected');
  
  // App state
  const [currentScreen, setCurrentScreen] = useState<'sessions' | 'session-detail'>('sessions');
  const [selectedSession, setSelectedSession] = useState<string | null>(null);
  const [sessions, setSessions] = useState<ListeningSession[]>([]);
  const [currentTrack, setCurrentTrack] = useState<CurrentTrack | null>(null);
  const [userVote, setUserVote] = useState<Vote | null>(null);

  // AIDEV-NOTE: Manual IP override for troubleshooting
  // Set this to your computer's IP address if auto-detection fails
  const MANUAL_IP_OVERRIDE: string | null = "10.0.2.15"; // Update this to your computer's actual IP

  useEffect(() => {
    // AIDEV-NOTE: Connect to Phoenix websocket - use correct IP for mobile/emulator
    // For Android emulator: 10.0.2.2:4000
    // For iOS simulator: localhost:4000 works
    // For physical device: use your computer's IP address (e.g., 192.168.1.X:4000)
    const getWebSocketUrl = () => {
      // AIDEV-NOTE: Connect to Phoenix UserSocket at /socket endpoint

        // If running on Expo web
        if (Platform.OS === 'web') {
          return "ws://localhost:4000/socket";
        }


      // Manual IP override for troubleshooting
      if (MANUAL_IP_OVERRIDE) {
        console.log(`🔧 Using manual IP override: ${MANUAL_IP_OVERRIDE}`);
        return `ws://${MANUAL_IP_OVERRIDE}:4000/socket`;
      }


      // For development with Expo dev server
      if (__DEV__) {
        // Get the dev server IP from Expo Constants
        const devServerUrl = Constants.expoConfig?.hostUri;

        console.log("Debug info:", {
          hostUri: Constants.expoConfig?.hostUri,
          platform: Platform.OS,
          isDevice: Constants.isDevice
        });

        // Try to get IP from hostUri
        let ip: string | null = null;

        if (devServerUrl) {
          const host = devServerUrl.split(':')[0];
          console.log(`Extracted host from hostUri: ${host}`);

          // Check if it's an Expo tunnel URL (contains .exp.direct)
          if (host.includes('.exp.direct')) {
            console.log(`❌ Detected Expo tunnel URL: ${host}`);
            console.log(`💡 Tunnel URLs don't work for websockets to localhost. Need to use LAN mode or manual IP.`);
            // Don't use tunnel URLs - they won't connect to your local Phoenix server
            ip = null;
          } else if (host !== 'localhost' && host !== '127.0.0.1') {
            // This should be a local IP address (192.168.x.x, 10.x.x.x, etc.)
            ip = host;
            console.log(`✅ Using local IP from hostUri: ${ip}`);
          }
        }

        if (ip && ip !== 'localhost' && ip !== '127.0.0.1') {
          return `ws://${ip}:4000/socket`;
        }

        // Platform-specific fallbacks
        if (Platform.OS === 'android') {
          if (Constants.isDevice) {
            // Physical Android device - this is the problematic case
            console.log("❌ Physical Android device but no local IP detected.");
            console.log("🔧 SOLUTION OPTIONS:");
            console.log("1. Switch Expo to LAN mode: expo start --lan");
            console.log("2. Or set MANUAL_IP_OVERRIDE in the code to your computer's WiFi IP");
            console.log("3. Find your IP with: ipconfig (Windows) or ifconfig (Mac/Linux)");
            console.log("💡 Using fallback IP 192.168.1.100 - update MANUAL_IP_OVERRIDE if different");
            return "ws://192.168.1.100:4000/socket";
          } else {
            // Android emulator
            console.log("✅ Using Android emulator IP: 10.0.2.2");
            return "ws://10.0.2.2:4000/socket";
          }
        } else {
          // iOS simulator
          console.log("✅ Using iOS simulator localhost");
          return "ws://localhost:4000/socket";
        }
      }

      // Production - you would set this to your actual server
      return "ws://your-production-server.com:4000/socket";
    };

    const websocketUrl = getWebSocketUrl();
    console.log(`Attempting to connect to: ${websocketUrl}`);

    const phoenixSocket = new Socket(websocketUrl, {
      params: { token: "guest_token" }, // Guest connection for now
      logger: (kind: string, msg: string, data: any) => {
        console.log(`Phoenix ${kind}: ${msg}`, data);
      }
    });

    phoenixSocket.onOpen(() => {
      console.log(`✅ Socket connected successfully to: ${websocketUrl}`);
      setConnectionStatus('connected');
    });

    phoenixSocket.onError((error: any) => {
      console.error(`❌ Socket error connecting to ${websocketUrl}:`, error);
      setConnectionStatus('disconnected');
    });

    phoenixSocket.onClose(() => {
      console.log(`🔌 Socket closed for: ${websocketUrl}`);
      setConnectionStatus('disconnected');
    });

    setSocket(phoenixSocket);
    setConnectionStatus('connecting');
    phoenixSocket.connect();

    return () => {
      if (phoenixSocket) {
        phoenixSocket.disconnect();
      }
    };
  }, []);

  useEffect(() => {
    if (socket && connectionStatus === 'connected') {
      // AIDEV-NOTE: Join the session:lobby channel for general updates
      const lobbyChannel = socket.channel("session:lobby", {});

      lobbyChannel.join()
        .receive("ok", (resp: any) => {
          console.log("Joined session:lobby channel successfully", resp);
          // Request current sessions list
          lobbyChannel.push("get_sessions", {});
        })
        .receive("error", (resp: any) => {
          console.error("Unable to join session:lobby channel", resp);
        });

      // Listen for sessions list updates
      lobbyChannel.on("sessions_list", (payload: any) => {
        console.log("Sessions list received:", payload);
        if (payload.sessions) {
          setSessions(payload.sessions);
        }
      });

      // Listen for session updates (when joining a specific session)
      lobbyChannel.on("session_update", (payload: any) => {
        console.log("Session update received:", payload);
        if (payload.session_id === selectedSession) {
          if (payload.current_track) {
            setCurrentTrack(payload.current_track);
          }
        }
      });

      // Listen for track changes
      lobbyChannel.on("track_changed", (payload: any) => {
        console.log("Track changed:", payload);
        if (payload.session_id === selectedSession) {
          setCurrentTrack(payload.track);
          setUserVote(null); // Reset vote for new track
        }
      });

      setChannel(lobbyChannel);

      return () => {
        if (lobbyChannel) {
          lobbyChannel.leave();
        }
      };
    }
  }, [socket, connectionStatus, selectedSession]);

  const handleSessionSelect = (sessionId: string) => {
    setSelectedSession(sessionId);
    setCurrentScreen('session-detail');
    
    // Join the specific session channel
    if (channel) {
      channel.push("join_session", { session_id: sessionId });
    }
    
    // Mock current track for demo - TODO: remove when backend is ready
    setTimeout(() => {
      const session = sessions.find(s => s.id === sessionId);
      if (session && session.currentTrack) {
        setCurrentTrack({
          id: 'track-' + sessionId,
          title: session.currentTrack,
          artist: session.artist || 'Unknown Artist',
          album: 'Demo Album',
          duration: 180,
          position: 45
        });
      }
    }, 500);
  };

  const handleBackToSessions = () => {
    setCurrentScreen('sessions');
    setSelectedSession(null);
    setCurrentTrack(null);
    setUserVote(null);
  };

  const handleVote = (rating: number) => {
    if (!currentTrack || !selectedSession) return;
    
    const vote: Vote = {
      trackId: currentTrack.id,
      rating: rating
    };
    
    setUserVote(vote);
    
    // Send vote to server
    if (channel) {
      channel.push("vote", {
        session_id: selectedSession,
        track_id: currentTrack.id,
        rating: rating
      });
    }
  };

  const getConnectionStatusColor = () => {
    switch (connectionStatus) {
      case 'connected': return '#10B981'; // green
      case 'connecting': return '#F59E0B'; // yellow
      case 'disconnected': return '#EF4444'; // red
    }
  };

  // Mock data for development - TODO: remove when backend is ready
  useEffect(() => {
    if (connectionStatus === 'connected' && sessions.length === 0) {
      // Add some mock sessions for development
      setTimeout(() => {
        setSessions([
          {
            id: '1',
            title: 'Indie Rock Discovery',
            host: 'MusicLover123',
            currentTrack: 'Somebody Else',
            artist: 'The 1975',
            participantCount: 12,
            isActive: true
          },
          {
            id: '2',
            title: 'Jazz Classics',
            host: 'JazzMaster',
            currentTrack: 'Take Five',
            artist: 'Dave Brubeck',
            participantCount: 8,
            isActive: true
          },
          {
            id: '3',
            title: 'Electronic Vibes',
            host: 'BeatDrop',
            currentTrack: 'Strobe',
            artist: 'Deadmau5',
            participantCount: 15,
            isActive: true
          }
        ]);
      }, 1000);
    }
  }, [connectionStatus]);

  const renderSessionsList = () => (
    <>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.logoContainer}>
          <View style={styles.logoCircle}>
            <Text style={styles.logoIcon}>♪</Text>
          </View>
        </View>
        <Text style={styles.appName}>Premiere Ecoute</Text>
        <View style={styles.statusContainer}>
          <View style={[styles.statusDot, { backgroundColor: getConnectionStatusColor() }]} />
          <Text style={styles.statusText}>
            {connectionStatus === 'connected' ? 'Live' : 
             connectionStatus === 'connecting' ? 'Connecting...' : 'Offline'}
          </Text>
        </View>
      </View>

      {/* Sessions List */}
      <View style={styles.mainContent}>
        <Text style={styles.sectionTitle}>Active Sessions</Text>
        
        {connectionStatus !== 'connected' ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyStateText}>Connecting to server...</Text>
          </View>
        ) : sessions.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyStateText}>No active sessions right now</Text>
          </View>
        ) : (
          <ScrollView style={styles.sessionsList} showsVerticalScrollIndicator={false}>
            {sessions.map((session) => (
              <TouchableOpacity 
                key={session.id} 
                style={styles.sessionItem}
                onPress={() => handleSessionSelect(session.id)}
              >
                <View style={styles.sessionHeader}>
                  <Text style={styles.sessionTitle}>{session.title}</Text>
                  <View style={styles.participantBadge}>
                    <Text style={styles.participantCount}>{session.participantCount}</Text>
                  </View>
                </View>
                <Text style={styles.sessionHost}>Hosted by {session.host}</Text>
                {session.currentTrack && (
                  <View style={styles.currentTrackInfo}>
                    <Text style={styles.trackTitle}>♪ {session.currentTrack}</Text>
                    <Text style={styles.trackArtist}>by {session.artist}</Text>
                  </View>
                )}
                <View style={styles.sessionFooter}>
                  <View style={styles.liveIndicator}>
                    <View style={styles.liveDot} />
                    <Text style={styles.liveText}>LIVE</Text>
                  </View>
                </View>
              </TouchableOpacity>
            ))}
          </ScrollView>
        )}
      </View>
    </>
  );

  const renderSessionDetail = () => {
    const session = sessions.find(s => s.id === selectedSession);
    if (!session) return null;

    return (
      <>
        {/* Header with Back Button */}
        <View style={styles.header}>
          <TouchableOpacity style={styles.backButton} onPress={handleBackToSessions}>
            <Text style={styles.backButtonText}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.sessionDetailTitle}>{session.title}</Text>
          <View style={styles.statusContainer}>
            <View style={[styles.statusDot, { backgroundColor: getConnectionStatusColor() }]} />
            <Text style={styles.statusText}>Live</Text>
          </View>
        </View>

        {/* Current Track Section */}
        <View style={styles.trackSection}>
          <Text style={styles.nowPlayingLabel}>NOW PLAYING</Text>
          
          {currentTrack ? (
            <View style={styles.trackCard}>
              <View style={styles.trackAlbumArt}>
                <Text style={styles.trackAlbumIcon}>♪</Text>
              </View>
              <View style={styles.trackInfo}>
                <Text style={styles.trackName}>{currentTrack.title}</Text>
                <Text style={styles.trackArtistName}>{currentTrack.artist}</Text>
                {currentTrack.album && (
                  <Text style={styles.trackAlbumName}>{currentTrack.album}</Text>
                )}
              </View>
            </View>
          ) : (
            <View style={styles.emptyTrack}>
              <Text style={styles.emptyTrackText}>Waiting for next track...</Text>
            </View>
          )}
        </View>

        {/* Voting Section */}
        {currentTrack && (
          <View style={styles.votingSection}>
            <Text style={styles.voteLabel}>Rate this track</Text>
            <View style={styles.starRating}>
              {[1, 2, 3, 4, 5].map((star) => (
                <TouchableOpacity
                  key={star}
                  style={styles.star}
                  onPress={() => handleVote(star)}
                >
                  <Text style={[
                    styles.starText,
                    { color: (userVote?.rating && star <= userVote.rating) ? '#FFD700' : '#666' }
                  ]}>
                    ★
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
            {userVote && (
              <Text style={styles.voteConfirmation}>
                You rated this track {userVote.rating} star{userVote.rating !== 1 ? 's' : ''}
              </Text>
            )}
          </View>
        )}

        {/* Session Info */}
        <View style={styles.sessionInfo}>
          <Text style={styles.sessionInfoText}>
            {session.participantCount} people listening • Hosted by {session.host}
          </Text>
        </View>
      </>
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar style="light" backgroundColor="#000000" />
      {currentScreen === 'sessions' ? renderSessionsList() : renderSessionDetail()}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000000',
  },
  header: {
    alignItems: 'center',
    paddingHorizontal: 32,
    paddingTop: 20,
    paddingBottom: 20,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  logoContainer: {
    marginBottom: 0,
  },
  logoCircle: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#8B4F99',
    justifyContent: 'center',
    alignItems: 'center',
  },
  logoIcon: {
    fontSize: 20,
    color: 'white',
    fontWeight: '300',
  },
  appName: {
    fontSize: 18,
    fontWeight: '600',
    color: 'white',
    letterSpacing: -0.5,
    flex: 1,
    textAlign: 'center',
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  statusText: {
    fontSize: 12,
    color: '#8E8E93',
    fontWeight: '500',
  },
  mainContent: {
    flex: 1,
    paddingHorizontal: 20,
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: '600',
    color: 'white',
    marginBottom: 20,
    paddingHorizontal: 12,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyStateText: {
    fontSize: 16,
    color: '#8E8E93',
    textAlign: 'center',
    fontWeight: '400',
  },
  sessionsList: {
    flex: 1,
  },
  sessionItem: {
    backgroundColor: '#1A1A1A',
    borderRadius: 16,
    padding: 20,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#2D2D2D',
  },
  sessionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  sessionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: 'white',
    flex: 1,
  },
  participantBadge: {
    backgroundColor: '#8B4F99',
    borderRadius: 12,
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  participantCount: {
    fontSize: 12,
    color: 'white',
    fontWeight: '600',
  },
  sessionHost: {
    fontSize: 14,
    color: '#8E8E93',
    marginBottom: 12,
  },
  currentTrackInfo: {
    marginBottom: 12,
  },
  trackTitle: {
    fontSize: 16,
    color: '#FFFFFF',
    fontWeight: '500',
    marginBottom: 4,
  },
  trackArtist: {
    fontSize: 14,
    color: '#8E8E93',
  },
  sessionFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  liveIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  liveDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: '#10B981',
  },
  liveText: {
    fontSize: 12,
    color: '#10B981',
    fontWeight: '600',
  },
  // Session Detail Styles
  backButton: {
    padding: 8,
  },
  backButtonText: {
    fontSize: 16,
    color: '#8B4F99',
    fontWeight: '500',
  },
  sessionDetailTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: 'white',
    flex: 1,
    textAlign: 'center',
  },
  trackSection: {
    paddingHorizontal: 20,
    paddingVertical: 24,
  },
  nowPlayingLabel: {
    fontSize: 12,
    color: '#8E8E93',
    fontWeight: '600',
    letterSpacing: 1,
    marginBottom: 16,
    textAlign: 'center',
  },
  trackCard: {
    backgroundColor: '#1A1A1A',
    borderRadius: 16,
    padding: 20,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#2D2D2D',
  },
  trackAlbumArt: {
    width: 60,
    height: 60,
    borderRadius: 8,
    backgroundColor: '#8B4F99',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  trackAlbumIcon: {
    fontSize: 24,
    color: 'white',
  },
  trackInfo: {
    flex: 1,
  },
  trackName: {
    fontSize: 18,
    fontWeight: '600',
    color: 'white',
    marginBottom: 4,
  },
  trackArtistName: {
    fontSize: 16,
    color: '#8E8E93',
    marginBottom: 2,
  },
  trackAlbumName: {
    fontSize: 14,
    color: '#666',
  },
  emptyTrack: {
    backgroundColor: '#1A1A1A',
    borderRadius: 16,
    padding: 40,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#2D2D2D',
  },
  emptyTrackText: {
    fontSize: 16,
    color: '#8E8E93',
    textAlign: 'center',
  },
  votingSection: {
    paddingHorizontal: 20,
    paddingVertical: 24,
    alignItems: 'center',
  },
  voteLabel: {
    fontSize: 16,
    color: 'white',
    fontWeight: '600',
    marginBottom: 20,
  },
  starRating: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 16,
  },
  star: {
    padding: 8,
  },
  starText: {
    fontSize: 32,
  },
  voteConfirmation: {
    fontSize: 14,
    color: '#10B981',
    textAlign: 'center',
  },
  sessionInfo: {
    paddingHorizontal: 20,
    paddingTop: 20,
    alignItems: 'center',
  },
  sessionInfoText: {
    fontSize: 14,
    color: '#8E8E93',
    textAlign: 'center',
  },
});
