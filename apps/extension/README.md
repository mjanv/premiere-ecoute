# Premiere Ecoute Twitch Extension

A Twitch overlay extension that allows viewers to save tracks from active Premiere Ecoute listening sessions to their Spotify playlists.

## Features

- 🎵 Shows currently playing track from active listening sessions
- 💾 One-click save to Spotify playlists
- 🎨 Synthwave/cyberpunk UI matching Premiere Ecoute branding
- 📱 Mobile and desktop responsive

## Development

### Prerequisites

- Node.js 18+
- npm or yarn

### Setup

```bash
cd apps/extension
npm install
```

### Development Server

```bash
npm run dev
```

This starts a webpack dev server with HTTPS (required for Twitch extensions) at https://localhost:8080

### Build

```bash
npm run build
```

This creates a production build in the `dist/` directory.

## Extension Structure

- `src/viewer.js` - Main entry point that initializes the extension
- `src/components/SaveTrackExtension.jsx` - Main React component
- `public/viewer.html` - HTML template for the extension
- `public/manifest.json` - Twitch extension manifest

## API Integration

The extension communicates with the Premiere Ecoute backend via:

- `GET /api/extension/current-track/:broadcaster_id` - Get current track
- `POST /api/extension/save-track` - Save track (logs request for now)

## Deployment

1. Build the extension: `npm run build`
2. Upload the contents of `dist/` to the Twitch Developer Console
3. Configure the extension with your backend URL
4. Submit for review

## Configuration

The extension requires the following environment variables on the backend:

- `TWITCH_EXTENSION_SECRET` - Shared secret for JWT verification