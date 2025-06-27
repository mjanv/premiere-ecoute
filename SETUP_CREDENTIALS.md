# API Credentials Setup Guide

## 🎵 Spotify API Setup

### Step 1: Create Spotify App
1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Log in with your Spotify account
3. Click "Create App"
4. Fill in the details:
   - **App Name**: `Premiere Ecoute`
   - **App Description**: `Live music rating platform for streamers`
   - **Website**: `http://localhost:4000` (for development)
   - **Redirect URI**: `http://localhost:4000/auth/spotify/callback`
5. Check the agreement boxes and click "Save"

### Step 2: Get Spotify Credentials
1. Click on your newly created app
2. Click "Settings" in the top right
3. Copy your **Client ID** and **Client Secret**

## 🎮 Twitch API Setup

### Step 1: Create Twitch Application
1. Go to [Twitch Developer Console](https://dev.twitch.tv/console/apps)
2. Log in with your Twitch account
3. Click "Register Your Application"
4. Fill in the details:
   - **Name**: `Premiere Ecoute`
   - **OAuth Redirect URLs**: `http://localhost:4000/auth/twitch/callback`
   - **Category**: `Website Integration`
5. Click "Create"

### Step 2: Get Twitch Credentials
1. Click "Manage" on your application
2. Copy your **Client ID**
3. Click "New Secret" to generate a **Client Secret**
4. Copy the secret immediately (it won't be shown again)

## 🔧 Configuration

### Option 1: Environment Variables (Recommended)
```bash
export SPOTIFY_CLIENT_ID="your_spotify_client_id_here"
export SPOTIFY_CLIENT_SECRET="your_spotify_client_secret_here"
export TWITCH_CLIENT_ID="your_twitch_client_id_here"
export TWITCH_CLIENT_SECRET="your_twitch_client_secret_here"
```

### Option 2: Create .env file
Create a `.env` file in the project root:
```bash
SPOTIFY_CLIENT_ID=your_spotify_client_id_here
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret_here
TWITCH_CLIENT_ID=your_twitch_client_id_here
TWITCH_CLIENT_SECRET=your_twitch_client_secret_here
```

## 🚀 Testing

After setting up credentials:

1. **Restart the Phoenix server**:
   ```bash
   mix phx.server
   ```

2. **Test Spotify Search**:
   - Visit `http://localhost:4000`
   - Search for albums (e.g., "dark side of the moon")
   - You should see real Spotify results

3. **Test Twitch Integration**:
   - Start a listening session
   - Twitch polls will be created automatically
   - Chat commands like `!vote 8` will be parsed

## 🛡️ Security Notes

- **Never commit credentials to git**
- Use environment variables in production
- The `.env` file is already in `.gitignore`
- Rotate secrets regularly

## 📞 Support

If you encounter issues:
1. Check that all credentials are correctly set
2. Verify redirect URLs match exactly
3. Ensure your Spotify/Twitch apps are properly configured
4. Check the Phoenix server logs for error details

