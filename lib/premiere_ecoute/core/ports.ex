defmodule PremiereEcoute.Core.Ports do
  @moduledoc """
  Port definitions for hexagonal architecture.
  These define the interfaces for external adapters.
  """

  alias PremiereEcoute.Core.Entities

  @doc """
  Port for streaming platform integrations (Twitch, YouTube, etc.)
  """
  defmodule StreamingPlatformPort do
    """
    defmodule StreamingPlatformPort do
    @moduledoc \"""
    Defines the interface for streaming platform integrations.
    """

    @type poll_option :: %{text: String.t(), votes: integer()}
    @type poll_result :: %{
            id: String.t(),
            question: String.t(),
            options: [poll_option()],
            status: :active | :ended,
            total_votes: integer()
          }

    @callback authenticate_user(code :: String.t()) ::
                {:ok, %{user_id: String.t(), access_token: String.t()}} | {:error, term()}

    @callback create_poll(
                channel_id :: String.t(),
                question :: String.t(),
                options :: [String.t()]
              ) ::
                {:ok, String.t()} | {:error, term()}

    @callback get_poll_results(poll_id :: String.t()) ::
                {:ok, poll_result()} | {:error, term()}

    @callback listen_to_chat(channel_id :: String.t(), callback :: function()) ::
                {:ok, pid()} | {:error, term()}
  end
end
