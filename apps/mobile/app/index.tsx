// AIDEV-NOTE: Simplified Premiere Ecoute Mobile App
// - Main page lists all active listening sessions from backend
// - Session detail page shows real-time viewer scores via websockets
// - TypeScript types exactly match backend channel responses
// - All other features removed as per requirements

import React, { useEffect, useState, useRef } from "react";
import { Text, View, StyleSheet, TouchableOpacity, SafeAreaView, ScrollView, Platform, Image, Animated } from "react-native";
import { StatusBar } from "expo-status-bar";
import { LinearGradient } from 'expo-linear-gradient';
import { Socket } from "phoenix";
import Constants from 'expo-constants';

// AIDEV-NOTE: TypeScript types matching backend channel test responses exactly
interface ListeningSession {
  id: string;
  album: {
    artist: string;
    cover_url: string;
    id: string;
    name: string;
    release_date: string;
    total_tracks: number;
    tracks: Array<{
      id: string;
      name: string;
      track_number: number;
    }>;
  };
  current_track: {
    id: string;
    name: string;
    track_number: number;
  };
  ended_at: string | null;
  started_at: string;
  status: "active" | "preparing" | "stopped";
  user: {
    email: string;
    id: string;
    role: "streamer" | "viewer" | "admin";
  };
}

interface SessionSummary {
  viewer_score: number;
}

export default function Index() {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [channel, setChannel] = useState<any>(null);
  const [connectionStatus, setConnectionStatus] = useState<'disconnected' | 'connecting' | 'connected'>('disconnected');

  // App state
  const [currentScreen, setCurrentScreen] = useState<'sessions' | 'session-detail'>('sessions');
  const [sessions, setSessions] = useState<ListeningSession[]>([]);
  const [viewerScore, setViewerScore] = useState<number | null>(null);
  const [selectedSessionData, setSelectedSessionData] = useState<ListeningSession | null>(null);
  const [currentTrack, setCurrentTrack] = useState<any | null>(null);

  // AIDEV-NOTE: Animation for live dot pulsing effect
  const pulseAnim = useRef(new Animated.Value(1)).current;

  // AIDEV-NOTE: Auto-refresh timer for sessions list
  const refreshIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // AIDEV-NOTE: Manual IP override for troubleshooting
  // Set this to your computer's IP address if auto-detection fails
  const MANUAL_IP_OVERRIDE: string | null = null; // Update this to your computer's actual IP

  // AIDEV-NOTE: Start pulsing animation for live dot
  useEffect(() => {
    const startPulse = () => {
      Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.5,
            duration: 1000,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 1000,
            useNativeDriver: true,
          }),
        ])
      ).start();
    };

    if (connectionStatus === 'connected') {
      startPulse();
    }
  }, [connectionStatus, pulseAnim]);

  // AIDEV-NOTE: Auto-refresh sessions list every 5 seconds
  useEffect(() => {
    const startAutoRefresh = () => {
      if (refreshIntervalRef.current) {
        clearInterval(refreshIntervalRef.current);
      }

      refreshIntervalRef.current = setInterval(() => {
        if (channel && connectionStatus === 'connected' && currentScreen === 'sessions') {
          console.log('Auto-refreshing sessions list...');
          requestSessions(channel);
        }
      }, 5000); // Refresh every 5 seconds
    };

    if (connectionStatus === 'connected' && currentScreen === 'sessions' && channel) {
      startAutoRefresh();
    } else {
      if (refreshIntervalRef.current) {
        clearInterval(refreshIntervalRef.current);
        refreshIntervalRef.current = null;
      }
    }

    // Cleanup on unmount
    return () => {
      if (refreshIntervalRef.current) {
        clearInterval(refreshIntervalRef.current);
      }
    };
  }, [connectionStatus, currentScreen, channel]);

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

      // Production - use the deployed Premiere Ecoute server
      return "wss://premiere-ecoute.fly.dev/socket";
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

  // AIDEV-NOTE: Function to request sessions from server
  const requestSessions = (channel: any) => {
    if (channel && connectionStatus === 'connected') {
      console.log('Requesting sessions list...');
      channel.push('get_sessions', {})
        .receive('ok', (response: any) => {
          console.log('get_sessions response:', response);
          if (response?.data) {
            const parsedSessions = response.data.map((sessionJson: string) => {
              try {
                return JSON.parse(sessionJson) as ListeningSession;
              } catch (e) {
                console.error('Failed to parse session JSON:', e);
                return null;
              }
            }).filter(Boolean);
            setSessions(parsedSessions);
            console.log(`Sessions updated: ${parsedSessions.length} active sessions`);
          }
        })
        .receive('error', (error: any) => {
          console.error('get_sessions error:', error);
        });
    }
  };

  useEffect(() => {
    if (socket && connectionStatus === 'connected') {
      // AIDEV-NOTE: Join sessions:lobby channel to get list of active sessions
      const lobbyChannel = socket.channel("sessions:lobby", {});

      lobbyChannel.join()
        .receive("ok", (resp: any) => {
          console.log("Joined sessions:lobby channel successfully", resp);
          // Request initial sessions list
          requestSessions(lobbyChannel);
        })
        .receive("error", (resp: any) => {
          console.error("Unable to join sessions:lobby channel", resp);
        });

      // Handle channel errors
      lobbyChannel.onError((payload: any) => {
        console.error("Channel errored:", payload);
      });

      // Listen for real-time session updates from server
      lobbyChannel.on('sessions_updated', (payload: any) => {
        console.log('Real-time sessions update received:', payload);
        if (payload.sessions) {
          const parsedSessions = payload.sessions.map((sessionJson: string) => {
            try {
              return JSON.parse(sessionJson) as ListeningSession;
            } catch (e) {
              console.error('Failed to parse session JSON:', e);
              return null;
            }
          }).filter(Boolean);
          setSessions(parsedSessions);
          console.log(`Real-time update: ${parsedSessions.length} active sessions`);
        }
      });

      setChannel(lobbyChannel);

      return () => {
        if (lobbyChannel) {
          lobbyChannel.leave();
        }
      };
    }
  }, [socket, connectionStatus]);

  const handleSessionSelect = (sessionId: string) => {
    const session = sessions.find(s => s.id === sessionId);
    if (!session) return;

    setSelectedSessionData(session);
    setCurrentScreen('session-detail');
    setViewerScore(null); // Reset viewer score

    // AIDEV-NOTE: Join specific session channel as per backend test
    if (socket) {
      const sessionChannel = socket.channel(`session:${sessionId}`, {});

      sessionChannel.join()
        .receive("ok", (resp: any) => {
          console.log(`Joined session:${sessionId} channel successfully`, resp);
        })
        .receive("error", (resp: any) => {
          console.error(`Unable to join session:${sessionId} channel`, resp);
        });

      // AIDEV-NOTE: Listen for session_summary events with viewer_score as per backend test
      sessionChannel.on("session_summary", (payload: SessionSummary) => {
        console.log("Session summary received:", payload);
        setViewerScore(payload.viewer_score);
      });

      // AIDEV-NOTE: Listen for track change events (next_track/previous_track)
      sessionChannel.on("track", (payload: any) => {
        console.log("Track change received:", payload);

        // Payload is already the track object, no need to parse JSON
        let track = payload;

        // If payload is a string, parse it
        if (typeof payload === 'string') {
          try {
            track = JSON.parse(payload);
          } catch (e) {
            console.error('Failed to parse track JSON:', e);
            return;
          }
        }

        console.log("Track data:", track);
        setCurrentTrack(track);

        // Update the current session data with new track info
        setSelectedSessionData(prevData => {
          if (prevData) {
            return {
              ...prevData,
              current_track: {
                id: track.id,
                name: track.name,
                track_number: track.track_number
              }
            };
          }
          return prevData;
        });
      });

      // Update channel reference
      setChannel(sessionChannel);
    }
  };

  const handleBackToSessions = () => {
    // Leave current session channel
    if (channel) {
      channel.leave();
    }

    setCurrentScreen('sessions');
    setSelectedSessionData(null);
    setViewerScore(null);
    setCurrentTrack(null);

    // Rejoin sessions lobby and immediately refresh
    if (socket && connectionStatus === 'connected') {
      const lobbyChannel = socket.channel("sessions:lobby", {});
      lobbyChannel.join()
        .receive("ok", () => {
          console.log('Rejoined sessions lobby, refreshing list...');
          requestSessions(lobbyChannel);
        });
      setChannel(lobbyChannel);
    }
  };

  // AIDEV-NOTE: Voting functionality removed as per requirements - app only displays viewer scores

  const getConnectionStatusColor = () => {
    switch (connectionStatus) {
      case 'connected': return '#10B981'; // green
      case 'connecting': return '#F59E0B'; // yellow
      case 'disconnected': return '#EF4444'; // red
    }
  };

  // AIDEV-NOTE: Mock data removed - using real backend data from channels

  const renderSessionsList = () => (
    <>
      {/* Header with Gradient */}
      <View style={styles.headerContainer}>
        <LinearGradient
          colors={['#9333ea', '#ec4899']}
          start={{ x: 0, y: 0.5 }}
          end={{ x: 1, y: 0.5 }}
          style={styles.headerGradient}
        >
          <View style={styles.header}>
            <Text style={styles.appName}>Premiere Ecoute</Text>
            <View style={styles.statusContainer}>
              {connectionStatus === 'connected' ? (
                <Animated.View
                  style={[
                    styles.statusDot,
                    {
                      backgroundColor: getConnectionStatusColor(),
                      transform: [{ scale: pulseAnim }]
                    }
                  ]}
                />
              ) : (
                <View style={[styles.statusDot, { backgroundColor: getConnectionStatusColor() }]} />
              )}
              <Text style={styles.statusText}>
                {connectionStatus === 'connected' ? 'Live' :
                 connectionStatus === 'connecting' ? 'Connecting...' : 'Offline'}
              </Text>
            </View>
          </View>
        </LinearGradient>
      </View>

      {/* Sessions List */}
      <LinearGradient
        colors={['#9333ea', '#ec4899']}
        start={{ x: 0, y: 0.5 }}
        end={{ x: 1, y: 0.5 }}
        style={styles.mainContent}
      >
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
            {sessions.filter(session => session.status === 'active').map((session) => (
              <TouchableOpacity
                key={session.id}
                style={styles.sessionItem}
                onPress={() => handleSessionSelect(session.id)}
              >
                <View style={styles.sessionContent}>
                  {/* Album Cover */}
                  <View style={styles.albumCoverContainer}>
                    {session.album.cover_url ? (
                      <Image
                        source={{ uri: session.album.cover_url }}
                        style={styles.albumCover}
                        resizeMode="cover"
                      />
                    ) : (
                      <LinearGradient
                        colors={['#9333ea', '#ec4899']}
                        start={{ x: 0, y: 0.5 }}
                        end={{ x: 1, y: 0.5 }}
                        style={styles.albumCoverPlaceholder}
                      >
                        <Text style={styles.albumCoverIcon}>♪</Text>
                      </LinearGradient>
                    )}
                    <View style={styles.liveIndicatorOverlay}>
                      <Animated.View
                        style={[
                          styles.liveDot,
                          { transform: [{ scale: pulseAnim }] }
                        ]}
                      />
                    </View>
                  </View>

                  {/* Session Info */}
                  <View style={styles.sessionInfo}>
                    <Text style={styles.albumName} numberOfLines={1}>{session.album.name}</Text>
                    <Text style={styles.artistName} numberOfLines={1}>{session.album.artist}</Text>
                    {session.current_track && (
                      <Text style={styles.currentTrack} numberOfLines={1}>
                        ♪ {session.current_track.name}
                      </Text>
                    )}
                    <Text style={styles.sessionMeta}>
                      Track {session.current_track?.track_number || 1} of {session.album.total_tracks}
                    </Text>
                  </View>

                  {/* Arrow */}
                  <View style={styles.arrowContainer}>
                    <Text style={styles.arrow}>›</Text>
                  </View>
                </View>
              </TouchableOpacity>
            ))}
          </ScrollView>
        )}
      </LinearGradient>
    </>
  );

  const renderSessionDetail = () => {
    if (!selectedSessionData) return null;

    return (
      <LinearGradient
        colors={['#9333ea', '#ec4899']}
        start={{ x: 0, y: 0.5 }}
        end={{ x: 1, y: 0.5 }}
        style={styles.sessionDetailContainer}
      >
        {/* Minimal Header */}
        <View style={styles.sessionDetailHeader}>
          <TouchableOpacity style={styles.backButtonMinimal} onPress={handleBackToSessions}>
            <Text style={styles.backButtonTextMinimal}>← Back</Text>
          </TouchableOpacity>
          <View style={styles.headerInfo}>
            <Text style={styles.trackNameHeader} numberOfLines={1}>
              {currentTrack?.name || selectedSessionData.current_track?.name || 'No Track'}
            </Text>
            <Text style={styles.albumNameHeader} numberOfLines={1}>
              {selectedSessionData.album.name} • {selectedSessionData.album.artist}
            </Text>
          </View>
        </View>

        {/* Centered Score with Glass Effect Album Cover */}
        <View style={styles.scoreWithCoverContainer}>
          {/* Glass Effect Container */}
          <View style={styles.glassEffectContainer}>
            {/* Smaller Blurred Album Cover Background */}
            {selectedSessionData.album.cover_url && (
              <>
                <Image
                  source={{ uri: selectedSessionData.album.cover_url }}
                  style={styles.smallBlurredAlbumCover}
                  resizeMode="cover"
                  blurRadius={6}
                />
                {/* Overlay for better text readability */}
                <View style={styles.smallAlbumCoverOverlay} />
              </>
            )}

            {/* Centered Score */}
            <View style={styles.centeredScoreContainer}>
              {viewerScore !== null ? (
                <Text style={styles.largeScoreValue}>{viewerScore.toFixed(1)}</Text>
              ) : (
                <Text style={styles.largeScoreValue}>--</Text>
              )}
            </View>
          </View>
        </View>

        {/* Track Progress - Real-time updates */}
        <View style={styles.trackProgress}>
          <Text style={styles.progressText}>
            Track {currentTrack?.track_number || selectedSessionData.current_track?.track_number || 1} of {selectedSessionData.album.total_tracks}
          </Text>
          <View style={styles.trackProgressBar}>
            <View style={[
              styles.trackProgressBarFill,
              { width: `${((currentTrack?.track_number || selectedSessionData.current_track?.track_number || 1) / selectedSessionData.album.total_tracks) * 100}%` }
            ]} />
          </View>
        </View>
      </LinearGradient>
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
  headerContainer: {
    overflow: 'hidden',
  },
  headerGradient: {
    paddingTop: Platform.OS === 'ios' ? 50 : 30,
  },
  header: {
    alignItems: 'center',
    paddingHorizontal: 32,
    paddingTop: 10,
    paddingBottom: 24,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  // AIDEV-NOTE: Logo removed as requested
  appName: {
    fontSize: 28,
    fontWeight: '700',
    color: 'white',
    letterSpacing: -0.5,
    flex: 1,
    textShadowColor: 'rgba(0,0,0,0.3)',
    textShadowOffset: { width: 0, height: 2 },
    textShadowRadius: 4,
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
    shadowColor: '#10B981',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 4,
    elevation: 4,
  },
  statusText: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.9)',
    fontWeight: '500',
  },
  mainContent: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 0,
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
    color: 'rgba(255,255,255,0.9)',
    textAlign: 'center',
    fontWeight: '400',
  },
  sessionsList: {
    flex: 1,
  },
  sessionItem: {
    backgroundColor: 'rgba(255,255,255,0.15)',
    borderRadius: 20,
    marginBottom: 16,
    marginHorizontal: 4,
    overflow: 'hidden',
    elevation: 8,
    shadowColor: 'rgba(0,0,0,0.3)',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  sessionContent: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
  },
  albumCoverContainer: {
    position: 'relative',
    marginRight: 16,
  },
  albumCover: {
    width: 80,
    height: 80,
    borderRadius: 12,
  },
  albumCoverPlaceholder: {
    width: 80,
    height: 80,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  albumCoverIcon: {
    fontSize: 32,
    color: 'white',
    fontWeight: '300',
  },
  liveIndicatorOverlay: {
    position: 'absolute',
    top: 8,
    right: 8,
    backgroundColor: 'rgba(16,185,129,0.9)',
    borderRadius: 8,
    padding: 4,
    flexDirection: 'row',
    alignItems: 'center',
  },
  sessionInfo: {
    flex: 1,
    justifyContent: 'center',
  },
  albumName: {
    fontSize: 18,
    fontWeight: '700',
    color: 'white',
    marginBottom: 4,
  },
  artistName: {
    fontSize: 16,
    fontWeight: '500',
    color: '#E5E5E5',
    marginBottom: 8,
  },
  currentTrack: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.95)',
    fontWeight: '600',
    marginBottom: 4,
  },
  sessionMeta: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.7)',
    fontWeight: '400',
  },
  arrowContainer: {
    marginLeft: 12,
  },
  arrow: {
    fontSize: 24,
    color: 'rgba(255,255,255,0.8)',
    fontWeight: '300',
  },
  // AIDEV-NOTE: Removed old session list styles, replaced with new horizontal layout
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#10B981',
    shadowColor: '#10B981',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 6,
    elevation: 4,
  },
  // Session Detail Styles - Redesigned
  sessionDetailContainer: {
    flex: 1,
  },
  sessionDetailHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 10,
  },
  backButtonMinimal: {
    padding: 8,
    marginRight: 16,
  },
  backButtonTextMinimal: {
    fontSize: 16,
    color: 'rgba(255,255,255,0.9)',
    fontWeight: '500',
  },
  headerInfo: {
    flex: 1,
  },
  trackNameHeader: {
    fontSize: 18,
    fontWeight: '700',
    color: 'white',
    marginBottom: 2,
  },
  albumNameHeader: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.8)',
    fontWeight: '400',
  },
  // Score with Glass Effect Album Cover Background
  scoreWithCoverContainer: {
    flex: 1,
    position: 'relative',
    justifyContent: 'center',
    alignItems: 'center',
  },
  glassEffectContainer: {
    position: 'relative',
    width: 360,
    height: 360,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 30,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
    shadowColor: 'rgba(0,0,0,0.3)',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.8,
    shadowRadius: 16,
    elevation: 12,
    overflow: 'hidden',
  },
  smallBlurredAlbumCover: {
    position: 'absolute',
    width: 330,
    height: 330,
    borderRadius: 20,
    opacity: 0.7,
    top: 15,
    left: 15,
  },
  smallAlbumCoverOverlay: {
    position: 'absolute',
    width: 330,
    height: 330,
    borderRadius: 20,
    backgroundColor: 'rgba(0,0,0,0.3)',
    top: 15,
    left: 15,
  },

  // Centered Score Container - Simple absolute positioning
  centeredScoreContainer: {
    position: 'absolute',
    top: 15,
    left: 15,
    width: 330,
    height: 330,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1,
  },
  largeScoreValue: {
    fontSize: 180,
    fontWeight: '900',
    color: 'white',
    textAlign: 'center',
    textShadowColor: 'rgba(0,0,0,0.5)',
    textShadowOffset: { width: 0, height: 6 },
    textShadowRadius: 12,
    lineHeight: 200,
  },
  // AIDEV-NOTE: Old styles removed and replaced with new gradient design
  // Track Progress - Simplified
  trackProgress: {
    paddingHorizontal: 40,
    paddingBottom: 40,
    alignItems: 'center',
  },
  progressText: {
    fontSize: 16,
    color: 'rgba(255,255,255,0.9)',
    fontWeight: '500',
    textAlign: 'center',
    marginBottom: 12,
  },
  trackProgressBar: {
    width: '100%',
    height: 8,
    backgroundColor: 'rgba(255,255,255,0.2)',
    borderRadius: 4,
    overflow: 'hidden',
    shadowColor: 'rgba(0,0,0,0.3)',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.5,
    shadowRadius: 4,
    elevation: 2,
  },
  trackProgressBarFill: {
    height: '100%',
    backgroundColor: 'rgba(255,255,255,0.8)',
    borderRadius: 4,
    shadowColor: 'rgba(255,255,255,0.5)',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 4,
    elevation: 1,
  },
  // AIDEV-NOTE: SessionInfo styles moved to new layout
});
