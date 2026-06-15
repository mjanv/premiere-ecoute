defmodule PremiereEcouteWeb.Podcasts.Studio.ShowFormLive do
  @moduledoc """
  Streamer studio: create or edit a podcast show, including its cover image. Editing is restricted
  to the show's owner.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Podcasts
  alias PremiereEcoute.Podcasts.Show

  # AIDEV-NOTE: dark form-control classes matching the playlists/automations form (the bare daisyUI
  # `<.input>` defaults render unstyled-white on the synthwave background).
  @field_class "w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm focus:border-purple-500 focus:outline-none"
  @checkbox_class "checkbox checkbox-sm border-gray-600 bg-gray-700"

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
        {:ok, socket |> put_flash(:error, gettext("Show not found")) |> redirect(to: ~p"/studio/podcasts")}
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
        {saved, cover_error} = maybe_upload_cover(socket, saved)

        socket
        |> put_flash(:info, gettext("Show saved"))
        |> maybe_cover_flash(cover_error)
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
          {:ok, updated} -> {updated, nil}
          {:error, reason} -> {show, reason}
        end

      [] ->
        {show, nil}
    end
  end

  defp maybe_cover_flash(socket, nil), do: socket

  defp maybe_cover_flash(socket, :cover_not_square),
    do: put_flash(socket, :error, gettext("Cover must be square — it was not saved"))

  defp maybe_cover_flash(socket, :cover_too_small),
    do: put_flash(socket, :error, gettext("Cover must be at least 1400×1400 — it was not saved"))

  defp maybe_cover_flash(socket, :cover_too_large),
    do: put_flash(socket, :error, gettext("Cover must be at most 3000×3000 — it was not saved"))

  defp maybe_cover_flash(socket, _other),
    do: put_flash(socket, :error, gettext("Cover image could not be read — it was not saved"))

  defp assign_form(socket, changeset), do: assign(socket, form: to_form(changeset, as: "show"))

  @impl true
  def render(assigns) do
    assigns = assign(assigns, field_class: @field_class, checkbox_class: @checkbox_class)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_page="podcasts">
      <div class="synthwave-bg min-h-screen text-white">
        <div class="max-w-2xl mx-auto px-6 py-12">
          <h1 class="text-2xl font-bold text-white mb-6">
            {if @action == :new, do: gettext("New show"), else: gettext("Edit show")}
          </h1>

          <.form
            for={@form}
            id="show-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4 rounded-xl bg-gray-800/50 border border-gray-700 p-6"
          >
            <.input field={@form[:title]} type="text" label={gettext("Title")} class={@field_class} required />
            <.input field={@form[:description]} type="textarea" label={gettext("Description")} class={@field_class} />
            <.input field={@form[:author]} type="text" label={gettext("Author")} class={@field_class} />
            <.input
              field={@form[:language]}
              type="text"
              label={gettext("Language (e.g. en, fr)")}
              class={@field_class}
            />
            <.input
              field={@form[:category]}
              type="select"
              label={gettext("Category")}
              options={@categories}
              prompt={gettext("Choose a category")}
              class={@field_class}
            />
            <.input
              field={@form[:explicit]}
              type="checkbox"
              label={gettext("Explicit content")}
              class={@checkbox_class}
            />

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">
                {gettext("Cover image (≥ 1400×1400)")}
              </label>
              <.live_file_input upload={@uploads.cover} class="text-sm text-gray-300" />
              <img
                :if={@show.cover_key}
                src={~p"/podcasts/shows/#{@show.id}/cover"}
                class="mt-2 w-24 h-24 rounded-lg object-cover"
              />
            </div>

            <button
              type="submit"
              class="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg text-sm font-medium transition-colors"
            >
              {gettext("Save show")}
            </button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
