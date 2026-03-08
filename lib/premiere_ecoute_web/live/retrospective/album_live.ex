defmodule PremiereEcouteWeb.Retrospective.AlbumLive do
  @moduledoc """
  Album detail page — shows album metadata, track list, and reviews.
  Viewers can write a standalone album review (not tied to any session).
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Review
  alias PremiereEcoute.Sessions.ReviewLikes
  alias PremiereEcoute.Sessions.Reviews

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    album = Discography.get_album(String.to_integer(id))

    if is_nil(album) do
      {:ok, push_navigate(socket, to: ~p"/discography/albums")}
    else
      reviews = Reviews.list_for_album(album.id)
      review_ids = Enum.map(reviews, & &1.id)
      sessions = ListeningSession.list_for_album(album.id)

      current_user = socket.assigns[:current_scope] && socket.assigns.current_scope.user

      liked_ids =
        if current_user,
          do: ReviewLikes.liked_review_ids(review_ids, current_user.id),
          else: MapSet.new()

      {:ok,
       socket
       |> assign(:album, album)
       |> assign(:sessions, sessions)
       |> assign(:reviews, reviews)
       |> assign(:liked_ids, liked_ids)
       |> assign(:review_modal_open, false)
       |> assign(:review_form, nil)
       |> assign(:editing_review, nil)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("open_review_modal", _params, socket) do
    current_scope = socket.assigns[:current_scope]
    album = socket.assigns.album

    existing =
      if current_scope && current_scope.user,
        do: Reviews.get_for_user_and_album(album.id, current_scope.user.id)

    changeset =
      if existing do
        Review.changeset(existing, Map.from_struct(existing))
      else
        Review.changeset(%Review{}, %{watched_on: Date.utc_today(), album_id: album.id})
      end

    {:noreply,
     socket
     |> assign(:review_modal_open, true)
     |> assign(:review_form, Phoenix.Component.to_form(changeset, as: :review))
     |> assign(:editing_review, existing)}
  end

  @impl true
  def handle_event("close_review_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:review_modal_open, false)
     |> assign(:review_form, nil)
     |> assign(:editing_review, nil)}
  end

  @impl true
  def handle_event("set_review_rating", %{"rating" => rating}, socket) do
    {value, _} = Float.parse(rating)
    changeset = Ecto.Changeset.put_change(socket.assigns.review_form.source, :rating, value)
    {:noreply, assign(socket, :review_form, Phoenix.Component.to_form(changeset, as: :review))}
  end

  @impl true
  def handle_event("toggle_review_like", _params, socket) do
    form = socket.assigns.review_form
    next = if form[:like].value == true, do: nil, else: true
    changeset = Ecto.Changeset.put_change(form.source, :like, next)
    {:noreply, assign(socket, :review_form, Phoenix.Component.to_form(changeset, as: :review))}
  end

  @impl true
  def handle_event("update_review_form", %{"review" => params}, socket) do
    # AIDEV-NOTE: keeps changeset in sync on every keystroke so rating/like events don't lose text
    changeset =
      Ecto.Changeset.cast(socket.assigns.review_form.source, params, [:content, :tags_input, :watched_on, :watched_before])

    {:noreply, assign(socket, :review_form, Phoenix.Component.to_form(changeset, as: :review))}
  end

  @impl true
  def handle_event("save_review", %{"review" => params}, socket) do
    current_scope = socket.assigns[:current_scope]
    album = socket.assigns.album

    if current_scope && current_scope.user do
      # AIDEV-NOTE: tags arrive as comma-separated string from the text input; convert to list
      params = normalize_review_params(params)

      result =
        case socket.assigns.editing_review do
          nil ->
            Reviews.create(current_scope.user, Map.merge(params, %{"album_id" => album.id}))

          review ->
            Reviews.update(review, params)
        end

      case result do
        {:ok, _} ->
          {:noreply,
           socket
           |> reload_reviews(album.id, current_scope.user)
           |> assign(:review_modal_open, false)
           |> assign(:review_form, nil)
           |> assign(:editing_review, nil)
           |> put_flash(:info, gettext("Review saved"))}

        {:error, changeset} ->
          {:noreply, assign(socket, :review_form, Phoenix.Component.to_form(changeset, as: :review))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("You must be logged in to write a review"))}
    end
  end

  @impl true
  def handle_event("delete_review", %{"id" => id}, socket) do
    current_scope = socket.assigns[:current_scope]
    album = socket.assigns.album

    if current_scope && current_scope.user do
      case Reviews.delete(String.to_integer(id), current_scope.user) do
        {:ok, _} ->
          {:noreply,
           socket
           |> reload_reviews(album.id, current_scope.user)
           |> put_flash(:info, gettext("Review deleted"))}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, gettext("Review not found"))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("You must be logged in to delete a review"))}
    end
  end

  @impl true
  def handle_event("toggle_like_review", %{"id" => id}, socket) do
    current_scope = socket.assigns[:current_scope]

    if current_scope && current_scope.user do
      {:ok, _} = ReviewLikes.toggle(String.to_integer(id), current_scope.user)
      {:noreply, reload_reviews(socket, socket.assigns.album.id, current_scope.user)}
    else
      {:noreply, put_flash(socket, :error, gettext("You must be logged in to like a review"))}
    end
  end

  defp reload_reviews(socket, album_id, user) do
    reviews = Reviews.list_for_album(album_id)
    review_ids = Enum.map(reviews, & &1.id)

    socket
    |> assign(:reviews, reviews)
    |> assign(:liked_ids, ReviewLikes.liked_review_ids(review_ids, user.id))
  end

  defp normalize_review_params(params) do
    tags =
      params
      |> Map.get("tags_input", "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    like =
      case Map.get(params, "like") do
        "true" -> true
        "false" -> false
        _ -> nil
      end

    params
    |> Map.put("tags", tags)
    |> Map.delete("tags_input")
    |> Map.put("like", like)
  end
end
