defmodule PremiereEcoute.Apis.TwitchApi do
  @moduledoc "Twitch API"

  require Logger

  defmodule Behavior do
    @moduledoc """
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

  @behaviour __MODULE__.Behavior

  alias PremiereEcoute.Core.Ports.StreamingPlatformPort

  @twitch_api_base "https://api.twitch.tv/helix"
  @twitch_oauth_base "https://id.twitch.tv/oauth2"

  @impl StreamingPlatformPort
  def authenticate_user(code) when is_binary(code) do
    client_id = Application.get_env(:premiere_ecoute, :twitch_client_id)
    client_secret = Application.get_env(:premiere_ecoute, :twitch_client_secret)
    redirect_uri = Application.get_env(:premiere_ecoute, :twitch_redirect_uri)

    if client_id && client_secret do
      token_url = "#{@twitch_oauth_base}/token"

      case Req.post(token_url,
             headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
             body:
               URI.encode_query(%{
                 client_id: client_id,
                 client_secret: client_secret,
                 code: code,
                 grant_type: "authorization_code",
                 redirect_uri: redirect_uri
               })
           ) do
        {:ok, %{status: 200, body: %{"access_token" => token, "refresh_token" => refresh_token}}} ->
          case get_user_info(token) do
            {:ok, user_info} ->
              {:ok,
               %{
                 user_id: user_info["id"],
                 access_token: token,
                 refresh_token: refresh_token,
                 username: user_info["login"],
                 display_name: user_info["display_name"]
               }}

            {:error, reason} ->
              {:error, reason}
          end

        {:ok, %{status: status, body: body}} ->
          Logger.error("Twitch OAuth failed: #{status} - #{inspect(body)}")
          {:error, "Twitch authentication failed"}

        {:error, reason} ->
          Logger.error("Twitch OAuth request failed: #{inspect(reason)}")
          {:error, "Network error during authentication"}
      end
    else
      {:error, "Twitch credentials not configured"}
    end
  end

  @impl StreamingPlatformPort
  def create_poll(channel_id, question, options)
      when is_binary(channel_id) and is_binary(question) and is_list(options) do
    case get_app_access_token() do
      {:ok, token} ->
        poll_url = "#{@twitch_api_base}/polls"

        formatted_choices =
          Enum.with_index(options, fn option, _index ->
            %{title: option}
          end)

        poll_data = %{
          broadcaster_id: channel_id,
          title: question,
          choices: formatted_choices,
          # 5 minutes
          duration: 300
        }

        case Req.post(poll_url,
               headers: [
                 {"Authorization", "Bearer #{token}"},
                 {"Client-Id", Application.get_env(:premiere_ecoute, :twitch_client_id)},
                 {"Content-Type", "application/json"}
               ],
               json: poll_data
             ) do
          {:ok, %{status: 200, body: %{"data" => [poll | _]}}} ->
            {:ok, poll["id"]}

          {:ok, %{status: status, body: body}} ->
            Logger.error("Twitch poll creation failed: #{status} - #{inspect(body)}")
            {:error, "Failed to create poll"}

          {:error, reason} ->
            Logger.error("Twitch poll request failed: #{inspect(reason)}")
            {:error, "Network error creating poll"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl StreamingPlatformPort
  def get_poll_results(poll_id) when is_binary(poll_id) do
    case get_app_access_token() do
      {:ok, token} ->
        poll_url = "#{@twitch_api_base}/polls?id=#{poll_id}"

        case Req.get(poll_url,
               headers: [
                 {"Authorization", "Bearer #{token}"},
                 {"Client-Id", Application.get_env(:premiere_ecoute, :twitch_client_id)}
               ]
             ) do
          {:ok, %{status: 200, body: %{"data" => [poll | _]}}} ->
            poll_result = %{
              id: poll["id"],
              question: poll["title"],
              options:
                Enum.map(poll["choices"] || [], fn choice ->
                  %{text: choice["title"], votes: choice["votes"] || 0}
                end),
              status: parse_poll_status(poll["status"]),
              total_votes: Enum.sum(Enum.map(poll["choices"] || [], &(&1["votes"] || 0)))
            }

            {:ok, poll_result}

          {:ok, %{status: status, body: body}} ->
            Logger.error("Twitch poll fetch failed: #{status} - #{inspect(body)}")
            {:error, "Failed to fetch poll results"}

          {:error, reason} ->
            Logger.error("Twitch poll request failed: #{inspect(reason)}")
            {:error, "Network error fetching poll"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl StreamingPlatformPort
  def listen_to_chat(channel_id, callback)
      when is_binary(channel_id) and is_function(callback, 1) do
    # This would typically use WebSocket connection to Twitch IRC
    # For now, we'll simulate with a simple process that could be extended
    pid =
      spawn(fn ->
        chat_listener_loop(channel_id, callback)
      end)

    {:ok, pid}
  end

  # Private helper functions

  defp get_user_info(access_token) do
    user_url = "#{@twitch_api_base}/users"

    case Req.get(user_url,
           headers: [
             {"Authorization", "Bearer #{access_token}"},
             {"Client-Id", Application.get_env(:premiere_ecoute, :twitch_client_id)}
           ]
         ) do
      {:ok, %{status: 200, body: %{"data" => [user | _]}}} ->
        {:ok, user}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch user info failed: #{status} - #{inspect(body)}")
        {:error, "Failed to get user info"}

      {:error, reason} ->
        Logger.error("Twitch user info request failed: #{inspect(reason)}")
        {:error, "Network error getting user info"}
    end
  end

  defp get_app_access_token do
    client_id = Application.get_env(:premiere_ecoute, :twitch_client_id)
    client_secret = Application.get_env(:premiere_ecoute, :twitch_client_secret)

    if client_id && client_secret do
      token_url = "#{@twitch_oauth_base}/token"

      case Req.post(token_url,
             headers: [{"Content-Type", "application/x-www-form-urlencoded"}],
             body:
               URI.encode_query(%{
                 client_id: client_id,
                 client_secret: client_secret,
                 grant_type: "client_credentials"
               })
           ) do
        {:ok, %{status: 200, body: %{"access_token" => token}}} ->
          {:ok, token}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Twitch app token failed: #{status} - #{inspect(body)}")
          {:error, "Twitch app authentication failed"}

        {:error, reason} ->
          Logger.error("Twitch app token request failed: #{inspect(reason)}")
          {:error, "Network error during app authentication"}
      end
    else
      {:error, "Twitch credentials not configured"}
    end
  end

  defp parse_poll_status("ACTIVE"), do: :active
  defp parse_poll_status("COMPLETED"), do: :ended
  defp parse_poll_status("TERMINATED"), do: :ended
  defp parse_poll_status("ARCHIVED"), do: :ended
  defp parse_poll_status(_), do: :ended

  defp chat_listener_loop(channel_id, callback) do
    # Simulate receiving chat messages
    # In a real implementation, this would connect to Twitch IRC WebSocket
    :timer.sleep(5000)

    sample_message = %{
      user: "viewer_#{:rand.uniform(1000)}",
      message: "Great song! I give it a #{:rand.uniform(10)}/10",
      timestamp: DateTime.utc_now()
    }

    callback.(sample_message)
    chat_listener_loop(channel_id, callback)
  end
end
