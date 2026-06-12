defmodule PremiereEcouteWeb.Podcasts.Studio.ShowFormLive do
  @moduledoc """
  Streamer studio: create or edit a podcast show, including its cover image. Editing is restricted
  to the show's owner.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Podcasts
  alias PremiereEcoute.Podcasts.Show

  @impl true
  def mount(params, _session, %{assigns: %{current_scope: scope}} = socket) do
    case load(params, scope) do
      {:ok, show, action} ->
        socket
        |> assign(action: action, show: show)
        |> assign(categories: Show.categories())
        |> assign_form(Podcasts.change_show(show))
        |> allow_upload(:cover, accept: ~w(.jpg .jpeg .png), max_entries: 1, max_file_size: 10_000_000)
        |> then(&{:ok, &1})

      :error ->
        {:ok, socket |> put_flash(:error, "Show not found") |> redirect(to: ~p"/studio/podcasts")}
    end
  end

  defp load(%{"id" => id}, scope) do
    case Podcasts.get_show(id) do
      %Show{user_id: uid} = show when uid == scope.user.id -> {:ok, show, :edit}
      _ -> :error
    end
  end

  defp load(_params, _scope), do: {:ok, %Show{}, :new}

  @impl true
  def handle_event("validate", %{"show" => params}, socket) do
    changeset = socket.assigns.show |> Podcasts.change_show(params) |> Map.put(:action, :validate)
    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"show" => params}, %{assigns: %{current_scope: scope, action: action, show: show}} = socket) do
    result =
      case action do
        :new -> Podcasts.create_show(Map.put(params, "user_id", scope.user.id))
        :edit -> Podcasts.update_show(show, params)
      end

    case result do
      {:ok, saved} ->
        saved = maybe_upload_cover(socket, saved)

        socket
        |> put_flash(:info, "Show saved")
        |> redirect(to: ~p"/studio/podcasts/#{saved.id}")
        |> then(&{:noreply, &1})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp maybe_upload_cover(socket, show) do
    entries =
      consume_uploaded_entries(socket, :cover, fn %{path: path}, entry ->
        {:ok, {Path.extname(entry.client_name), File.read!(path)}}
      end)

    case entries do
      [{ext, bytes} | _] ->
        case Podcasts.upload_cover(show, ext, bytes) do
          {:ok, updated} -> updated
          _ -> show
        end

      [] ->
        show
    end
  end

  defp assign_form(socket, changeset), do: assign(socket, form: to_form(changeset, as: "show"))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto p-6">
        <h1 class="text-2xl font-bold mb-6">{if @action == :new, do: "New show", else: "Edit show"}</h1>

        <.form for={@form} id="show-form" phx-change="validate" phx-submit="save" class="space-y-4">
          <.input field={@form[:title]} type="text" label="Title" required />
          <.input field={@form[:description]} type="textarea" label="Description" />
          <.input field={@form[:author]} type="text" label="Author" />
          <.input field={@form[:language]} type="text" label="Language (e.g. en, fr)" />
          <.input field={@form[:category]} type="select" label="Category" options={@categories} prompt="Choose a category" />
          <.input field={@form[:explicit]} type="checkbox" label="Explicit content" />

          <div>
            <label class="block text-sm font-medium mb-1">Cover image (≥ 1400×1400)</label>
            <.live_file_input upload={@uploads.cover} />
            <img :if={@show.cover_url} src={@show.cover_url} class="mt-2 w-24 h-24 rounded object-cover" />
          </div>

          <.button type="submit">Save show</.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
