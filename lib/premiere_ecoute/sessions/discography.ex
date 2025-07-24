defmodule PremiereEcoute.Sessions.Discography do
  @moduledoc """
  Context module for managing music discography data.

  The Discography context handles the storage and retrieval of music catalog data
  including albums and tracks sourced from Spotify's API. This data forms the foundation
  for listening sessions where users can discover, rate, and discuss music.

  ## Core Entities

  - `Album` - Represents a music album with metadata and associated tracks
  - `Track` - Individual songs within an album with track-specific information

  ## Data Flow

  1. **Discovery**: Users search for albums through the Spotify API integration
  2. **Storage**: Selected albums and their tracks are persisted locally
  3. **Sessions**: Albums are used as the basis for listening sessions
  4. **Interaction**: Users can rate and discuss individual tracks during sessions

  ## Key Features

  - Integration with Spotify's music catalog
  - Local caching of album and track metadata
  - Support for listening session workflows
  - Track-level granularity for user interactions

  ## Usage

  This context module serves as the boundary between the application's session
  management and the underlying music catalog data. It provides a clean interface
  for working with albums and tracks without exposing the complexity of external
  API integrations.

  ## Related Modules

  - `PremiereEcoute.Sessions.Discography.Album` - Album schema and operations
  - `PremiereEcoute.Sessions.Discography.Track` - Track schema and operations
  - `PremiereEcoute.APIs.SpotifyAPI` - External API integration for music data
  """
end
