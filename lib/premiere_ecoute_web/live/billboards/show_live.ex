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
        |> put_flash(:error, "Billboard not found")
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
          |> put_flash(:error, "You don't have permission to access this billboard")
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
        |> put_flash(:info, "Billboard activated! Users can now submit playlists.")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to activate billboard")}
    end
  end

  @impl true
  def handle_event("stop", _params, socket) do
    case Billboards.stop_billboard(socket.assigns.billboard) do
      {:ok, billboard} ->
        socket
        |> assign(:billboard, billboard)
        |> put_flash(:info, "Billboard stopped. No more submissions will be accepted.")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to stop billboard")}
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
        |> put_flash(:info, "Submission removed")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, :invalid_index} ->
        {:noreply, put_flash(socket, :error, "Invalid submission")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove submission")}
    end
  end

  @impl true
  def handle_event("generate", _params, socket) do
    billboard = socket.assigns.billboard

    if length(billboard.submissions || []) == 0 do
      {:noreply, put_flash(socket, :error, "No submissions available to generate billboard")}
    else
      # AIDEV-NOTE: Generate billboard and store in cache instead of redirecting
      case Billboards.generate_billboard_display(billboard) do
        {:ok, generated_billboard} ->
          cache_key = "billboard_#{billboard.billboard_id}"
          Cache.put(:billboards, cache_key, generated_billboard)

          socket
          |> assign(:cache_status, :ready)
          |> put_flash(:info, "Billboard generated and cached successfully!")
          |> then(fn socket -> {:noreply, socket} end)

        {:error, reason} ->
          error_msg =
            case reason do
              :no_submissions -> "No submissions available to generate billboard"
              _ -> "Failed to generate billboard"
            end

          {:noreply, put_flash(socket, :error, error_msg)}
      end
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
        |> put_flash(:info, "Billboard deleted successfully")
        |> redirect(to: ~p"/billboards")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _changeset} ->
        socket
        |> assign(:show_delete_modal, false)
        |> put_flash(:error, "Failed to delete billboard")
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
        |> put_flash(:info, "Billboard title updated successfully")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, changeset} ->
        socket
        |> assign(:title_form, to_form(changeset))
        |> put_flash(:error, "Failed to update billboard title")
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
    cache_key = "billboard_#{billboard_id}"

    case Cache.get(:billboards, cache_key) do
      {:ok, nil} -> :not_ready
      {:ok, _} -> :ready
      {:error, _} -> :not_ready
    end
  end

  defp billboard_status_badge(assigns) do
    class =
      case assigns.status do
        :created -> "bg-gray-600/20 text-gray-300 border-gray-500/30"
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

  # AIDEV-NOTE: Display cache status badge for generated billboard versions
  defp cache_status_badge(assigns) do
    {class, text} =
      case assigns.cache_status do
        :ready -> {"bg-green-600/20 text-green-300 border-green-500/30", "Version Ready"}
        :not_ready -> {"bg-yellow-600/20 text-yellow-300 border-yellow-500/30", "Not Generated"}
        _ -> {"bg-gray-600/20 text-gray-300 border-gray-500/30", "Unknown"}
      end

    assigns = assign(assigns, :class, class) |> assign(:text, text)

    ~H"""
    <span class={"inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border #{@class}"}>
      {@text}
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
end
