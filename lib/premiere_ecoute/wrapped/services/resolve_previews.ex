defmodule PremiereEcoute.Wrapped.Services.ResolvePreviews do
  @moduledoc """
  Resolves the 30 s preview played behind each card.

  Preview URLs are signed and expire, so they are resolved when the page is opened and never stored.
  """

  alias PremiereEcoute.Apis

  @doc "Lists one preview URL (or `nil`) per card, in card order. Returns no URL at all when sound is disabled."
  @spec previews([map()]) :: [String.t() | nil]
  def previews(cards) do
    if sound?() do
      cards
      |> Task.async_stream(&preview/1, timeout: 5_000, on_timeout: :kill_task)
      |> Enum.map(fn
        {:ok, url} -> url
        _ -> nil
      end)
    else
      Enum.map(cards, fn _ -> nil end)
    end
  end

  # Sound is optional: a failing lookup must never take the page down with it
  defp preview(%{"preview" => %{"artist" => artist, "name" => name}}) do
    case Apis.deezer().get_track_preview(artist, name) do
      {:ok, url} -> url
      _ -> nil
    end
  rescue
    _ -> nil
  catch
    :exit, _ -> nil
  end

  defp preview(_card), do: nil

  defp sound?, do: Application.get_env(:premiere_ecoute, PremiereEcoute.Wrapped, [])[:sound] || false
end
