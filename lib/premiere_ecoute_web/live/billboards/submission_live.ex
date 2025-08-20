defmodule PremiereEcouteWeb.Billboards.SubmissionLive do
  @moduledoc """
  Public LiveView for submitting playlists to active billboards.

  Accessible to non-authenticated users when billboard is active.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Billboard

  @impl true
  def mount(%{"id" => billboard_id}, _session, socket) do
    case Billboards.get_billboard(billboard_id) do
      nil ->
        socket
        |> put_flash(:error, gettext("Billboard not found"))
        |> redirect(to: ~p"/")
        |> then(fn socket -> {:ok, socket} end)

      %Billboard{status: :created} = _billboard ->
        socket
        |> put_flash(:error, gettext("This billboard is not yet active"))
        |> redirect(to: ~p"/")
        |> then(fn socket -> {:ok, socket} end)

      %Billboard{status: :stopped} = billboard ->
        socket
        |> assign(:page_title, gettext("Billboard Stopped - %{title}", title: billboard.title))
        |> assign(:billboard, billboard)
        |> assign(:url, "")
        |> assign(:pseudo, "")
        |> assign(:error_message, nil)
        |> assign(:success_message, nil)
        |> assign(:deletion_token, "")
        |> assign(:deletion_error, nil)
        |> assign(:deletion_success, nil)
        |> assign(:generated_token, nil)
        |> assign(:billboard_stopped, true)
        |> then(fn socket -> {:ok, socket} end)

      %Billboard{} = billboard ->
        socket
        |> assign(:page_title, gettext("Submit to %{title}", title: billboard.title))
        |> assign(:billboard, billboard)
        |> assign(:url, "")
        |> assign(:pseudo, "")
        |> assign(:error_message, nil)
        |> assign(:success_message, nil)
        |> assign(:deletion_token, "")
        |> assign(:deletion_error, nil)
        |> assign(:deletion_success, nil)
        |> assign(:generated_token, nil)
        |> assign(:billboard_stopped, false)
        |> then(fn socket -> {:ok, socket} end)
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, url: Map.get(params, "url", ""), pseudo: Map.get(params, "pseudo", ""), error_message: nil)}
  end

  @impl true
  def handle_event("validate_deletion", params, socket) do
    {:noreply, assign(socket, deletion_token: Map.get(params, "deletion_token", ""), deletion_error: nil)}
  end

  @impl true
  def handle_event("submit", params, socket) do
    url = Map.get(params, "url", "")
    pseudo = Map.get(params, "pseudo", "")
    billboard = socket.assigns.billboard

    case validate_url(url) do
      {:ok, clean_url} ->
        case Billboards.add_submission(billboard, clean_url, pseudo) do
          {:ok, _updated_billboard, deletion_token} ->
            socket
            |> assign(:url, "")
            |> assign(:pseudo, "")
            |> assign(:success_message, gettext("Playlist submitted successfully!"))
            |> assign(:error_message, nil)
            |> assign(:generated_token, deletion_token)
            |> then(fn socket -> {:noreply, socket} end)

          {:error, :url_already_exists} ->
            {:noreply, assign(socket, error_message: gettext("This playlist has already been submitted"))}

          {:error, :billboard_not_active} ->
            {:noreply, assign(socket, error_message: gettext("This billboard is no longer accepting submissions"))}

          {:error, _} ->
            {:noreply, assign(socket, error_message: gettext("Failed to submit playlist. Please try again."))}
        end

      {:error, message} ->
        {:noreply, assign(socket, error_message: message)}
    end
  end

  @impl true
  def handle_event("delete_submission", params, socket) do
    deletion_token = Map.get(params, "deletion_token", "")
    billboard = socket.assigns.billboard

    case Billboards.remove_submission_by_token(billboard, deletion_token) do
      {:ok, updated_billboard} ->
        socket
        |> assign(:billboard, updated_billboard)
        |> assign(:deletion_token, "")
        |> assign(:deletion_success, gettext("Playlist successfully removed!"))
        |> assign(:deletion_error, nil)
        |> then(fn socket -> {:noreply, socket} end)

      {:error, :token_not_found} ->
        {:noreply, assign(socket, deletion_error: gettext("Invalid deletion code. Please check your code and try again."))}

      {:error, _} ->
        {:noreply, assign(socket, deletion_error: gettext("Failed to delete playlist. Please try again."))}
    end
  end

  defp validate_url(url) do
    cond do
      String.match?(url, ~r/https:\/\/open\.spotify\.com\/playlist\/[a-zA-Z0-9]+/) ->
        {:ok, url}

      String.match?(url, ~r/https:\/\/www\.deezer\.com\/[a-z]+\/playlist\/[0-9]+/) ->
        {:ok, url}

      true ->
        {:error, gettext("Please use a valid playlist URL from Spotify or Deezer")}
    end
  end
end
