defmodule PremiereEcouteWeb.Billboards.ShowLive do
  @moduledoc """
  LiveView for managing a billboard.

  Allows the owner to:
  - Change billboard status (active/stopped)
  - View and delete submissions
  - Generate the billboard display
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Billboard
  alias PremiereEcouteCore.Cache
  alias PremiereEcouteWeb.Layouts

  @impl true
  def mount(%{"id" => billboard_id}, _session, socket) do
    case Billboards.get_billboard(billboard_id) do
      nil ->
        socket
        |> put_flash(:error, gettext("Billboard not found"))
        |> redirect(to: ~p"/home")
        |> then(fn socket -> {:ok, socket} end)

      %Billboard{} = billboard ->
        current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

        if current_user.id == billboard.user_id do
          # AIDEV-NOTE: Check cache for generated billboard version status
          cache_status = check_billboard_cache_status(billboard.billboard_id)

          socket
          |> assign(:page_title, billboard.title)
          |> assign(:billboard, billboard)
          |> assign(:submissions, billboard.submissions || [])
          |> assign(:show_delete_modal, false)
          |> assign(:cache_status, cache_status)
          |> assign(:show_edit_modal, false)
          |> assign(:title_form, to_form(%{"title" => billboard.title}))
          |> then(fn socket -> {:ok, socket} end)
        else
          socket
          |> put_flash(:error, gettext("You don't have permission to access this billboard"))
          |> redirect(to: ~p"/home")
          |> then(fn socket -> {:ok, socket} end)
        end
    end
  end

  @impl true
  def handle_event("activate", _params, socket) do
    case Billboards.activate_billboard(socket.assigns.billboard) do
      {:ok, billboard} ->
        socket
        |> assign(:billboard, billboard)
        |> put_flash(:info, gettext("Billboard activated! Users can now submit playlists."))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to activate billboard"))}
    end
  end

  @impl true
  def handle_event("stop", _params, socket) do
    case Billboards.stop_billboard(socket.assigns.billboard) do
      {:ok, billboard} ->
        socket
        |> assign(:billboard, billboard)
        |> put_flash(:info, gettext("Billboard stopped. No more submissions will be accepted."))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to stop billboard"))}
    end
  end

  @impl true
  def handle_event("remove_submission", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    case Billboards.remove_submission(socket.assigns.billboard, index) do
      {:ok, billboard} ->
        socket
        |> assign(:billboard, billboard)
        |> assign(:submissions, billboard.submissions || [])
        |> put_flash(:info, gettext("Submission removed"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, :invalid_index} ->
        {:noreply, put_flash(socket, :error, gettext("Invalid submission"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to remove submission"))}
    end
  end

  @impl true
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl true
  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    billboard = socket.assigns.billboard

    case Billboards.delete_billboard(billboard) do
      {:ok, _} ->
        socket
        |> put_flash(:info, gettext("Billboard deleted successfully"))
        |> redirect(to: ~p"/billboards")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _changeset} ->
        socket
        |> assign(:show_delete_modal, false)
        |> put_flash(:error, gettext("Failed to delete billboard"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_event("show_edit_modal", _params, socket) do
    {:noreply, assign(socket, :show_edit_modal, true)}
  end

  @impl true
  def handle_event("hide_edit_modal", _params, socket) do
    socket
    |> assign(:show_edit_modal, false)
    |> assign(:title_form, to_form(%{"title" => socket.assigns.billboard.title}))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("update_title", %{"title" => new_title}, socket) do
    billboard = socket.assigns.billboard

    case Billboards.update_billboard(billboard, %{title: new_title}) do
      {:ok, updated_billboard} ->
        socket
        |> assign(:billboard, updated_billboard)
        |> assign(:page_title, updated_billboard.title)
        |> assign(:show_edit_modal, false)
        |> assign(:title_form, to_form(%{"title" => updated_billboard.title}))
        |> put_flash(:info, gettext("Billboard title updated successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, changeset} ->
        socket
        |> assign(:title_form, to_form(changeset))
        |> put_flash(:error, gettext("Failed to update billboard title"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_event("validate_title", %{"title" => new_title}, socket) do
    form = to_form(%{"title" => new_title})
    {:noreply, assign(socket, :title_form, form)}
  end

  # Helper functions

  # AIDEV-NOTE: Check if billboard is available in cache
  defp check_billboard_cache_status(billboard_id) do
    case Cache.get(:billboards, billboard_id) do
      {:ok, nil} -> :not_ready
      {:ok, _} -> :ready
      {:error, _} -> :not_ready
    end
  end

  defp billboard_status_badge(assigns) do
    class =
      case assigns.status do
        :created -> "bg-blue-600/20 text-blue-300 border-blue-500/30"
        :active -> "bg-green-600/20 text-green-300 border-green-500/30"
        :stopped -> "bg-red-600/20 text-red-300 border-red-500/30"
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <span class={"inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border #{@class}"}>
      {String.capitalize(to_string(@status))}
    </span>
    """
  end

  defp get_submission_url(%{url: url}), do: url
  defp get_submission_url(%{"url" => url}), do: url
  defp get_submission_url(url) when is_binary(url), do: url

  defp get_submission_pseudo(%{pseudo: pseudo}) when is_binary(pseudo) and pseudo != "", do: pseudo
  defp get_submission_pseudo(%{"pseudo" => pseudo}) when is_binary(pseudo) and pseudo != "", do: pseudo
  defp get_submission_pseudo(_), do: nil

  defp get_submission_date(%{submitted_at: date}), do: date
  defp get_submission_date(%{"submitted_at" => date}), do: date
  defp get_submission_date(_), do: nil

  defp format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d at %H:%M UTC")
  end

  defp format_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> format_date(datetime)
      _ -> date_string
    end
  end

  defp format_date(_), do: "Unknown"

  defp simple_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp simple_date(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> simple_date()
  end

  defp simple_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> simple_date(datetime)
      _ -> date_string
    end
  end

  defp simple_date(_), do: gettext("Unknown")
end
