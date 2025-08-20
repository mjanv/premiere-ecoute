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

          # AIDEV-NOTE: Sort submissions by reverse chronological order (newest first)
          sorted_submissions = sort_submissions_by_date(billboard.submissions || [])

          socket
          |> assign(:page_title, billboard.title)
          |> assign(:billboard, billboard)
          |> assign(:submissions, sorted_submissions)
          |> assign(:show_delete_modal, false)
          |> assign(:cache_status, cache_status)
          |> assign(:show_edit_modal, false)
          |> assign(:title_form, to_form(%{"title" => billboard.title}))
          |> assign(:search_query, "")
          |> assign(:review_filter, "all")
          |> assign(:filtered_submissions, filter_submissions(sorted_submissions, "", "all"))
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
        submissions = sort_submissions_by_date(billboard.submissions || [])
        filtered_submissions = filter_submissions(submissions, socket.assigns.search_query, socket.assigns.review_filter)

        socket
        |> assign(:billboard, billboard)
        |> assign(:submissions, submissions)
        |> assign(:filtered_submissions, filtered_submissions)
        |> put_flash(:info, gettext("Submission removed"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, :invalid_index} ->
        {:noreply, put_flash(socket, :error, gettext("Invalid submission"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to remove submission"))}
    end
  end

  @impl true
  def handle_event("toggle_review", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    case Billboards.toggle_submission_review(socket.assigns.billboard, index) do
      {:ok, billboard} ->
        submissions = sort_submissions_by_date(billboard.submissions || [])
        filtered_submissions = filter_submissions(submissions, socket.assigns.search_query, socket.assigns.review_filter)

        socket
        |> assign(:billboard, billboard)
        |> assign(:submissions, submissions)
        |> assign(:filtered_submissions, filtered_submissions)
        |> put_flash(:info, gettext("Submission review status updated"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, :invalid_index} ->
        {:noreply, put_flash(socket, :error, gettext("Invalid submission"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update review status"))}
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

  @impl true
  def handle_event("search", params, socket) do
    IO.puts("=== SEARCH EVENT TRIGGERED ===")
    IO.inspect(params, label: "SEARCH PARAMS")

    query =
      case params do
        %{"query" => q} -> q
        %{"_target" => ["query"], "query" => q} -> q
        _ -> ""
      end

    IO.puts("Search query: #{query}")

    submissions = socket.assigns.submissions
    review_filter = socket.assigns.review_filter
    filtered_submissions = filter_submissions(submissions, query, review_filter)

    IO.puts("Filtered from #{length(submissions)} to #{length(filtered_submissions)}")

    socket
    |> assign(:search_query, query)
    |> assign(:filtered_submissions, filtered_submissions)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("filter_review", params, socket) do
    IO.puts("=== FILTER EVENT TRIGGERED ===")
    IO.inspect(params, label: "FILTER PARAMS")

    filter =
      case params do
        %{"filter" => f} -> f
        _ -> "all"
      end

    submissions = socket.assigns.submissions
    search_query = socket.assigns.search_query
    filtered_submissions = filter_submissions(submissions, search_query, filter)

    socket
    |> assign(:review_filter, filter)
    |> assign(:filtered_submissions, filtered_submissions)
    |> then(fn socket -> {:noreply, socket} end)
  end

  # Helper functions

  # AIDEV-NOTE: Sort submissions by date (newest first)
  defp sort_submissions_by_date(submissions) do
    Enum.sort(submissions, fn sub1, sub2 ->
      date1 = get_submission_date(sub1)
      date2 = get_submission_date(sub2)

      case {date1, date2} do
        {nil, nil} -> false
        {nil, _} -> false
        {_, nil} -> true
        {d1, d2} -> compare_dates(d1, d2) == :gt
      end
    end)
  end

  # AIDEV-NOTE: Compare dates handling both DateTime and string formats
  defp compare_dates(%DateTime{} = d1, %DateTime{} = d2), do: DateTime.compare(d1, d2)

  defp compare_dates(d1, d2) when is_binary(d1) and is_binary(d2) do
    case {DateTime.from_iso8601(d1), DateTime.from_iso8601(d2)} do
      {{:ok, dt1, _}, {:ok, dt2, _}} -> DateTime.compare(dt1, dt2)
      _ -> :eq
    end
  end

  defp compare_dates(%DateTime{} = d1, d2) when is_binary(d2) do
    case DateTime.from_iso8601(d2) do
      {:ok, dt2, _} -> DateTime.compare(d1, dt2)
      _ -> :gt
    end
  end

  defp compare_dates(d1, %DateTime{} = d2) when is_binary(d1) do
    case DateTime.from_iso8601(d1) do
      {:ok, dt1, _} -> DateTime.compare(dt1, d2)
      _ -> :lt
    end
  end

  defp compare_dates(_, _), do: :eq

  # AIDEV-NOTE: Filter submissions based on search query and review status
  defp filter_submissions(submissions, query, review_filter) do
    submissions
    |> filter_by_search(query)
    |> filter_by_review_status(review_filter)
  end

  defp filter_by_search(submissions, ""), do: submissions

  defp filter_by_search(submissions, query) when is_binary(query) do
    query_lower = String.downcase(query)

    Enum.filter(submissions, fn submission ->
      url_match =
        submission
        |> get_submission_url()
        |> String.downcase()
        |> String.contains?(query_lower)

      pseudo_match =
        case get_submission_pseudo(submission) do
          nil ->
            false

          pseudo ->
            pseudo
            |> String.downcase()
            |> String.contains?(query_lower)
        end

      url_match or pseudo_match
    end)
  end

  defp filter_by_review_status(submissions, "all"), do: submissions

  defp filter_by_review_status(submissions, "reviewed") do
    Enum.filter(submissions, &get_submission_reviewed/1)
  end

  defp filter_by_review_status(submissions, "unreviewed") do
    Enum.filter(submissions, fn submission -> not get_submission_reviewed(submission) end)
  end

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

  # AIDEV-NOTE: Helper function to get review status from submission
  defp get_submission_reviewed(%{"reviewed" => reviewed}) when is_boolean(reviewed), do: reviewed
  defp get_submission_reviewed(%{reviewed: reviewed}) when is_boolean(reviewed), do: reviewed
  defp get_submission_reviewed(_), do: false

  defp format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
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
