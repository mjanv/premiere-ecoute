defmodule PremiereEcouteWeb.Podcasts.Studio.EpisodeFormLive do
  @moduledoc """
  Streamer studio: upload a new episode (MP3, processed asynchronously) or edit an existing
  episode's metadata. Restricted to the owning streamer.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Podcasts
  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Show

  # Dark form-control class matching the playlists/automations form (bare daisyUI
  # `<.input>` defaults render unstyled-white on the synthwave background).
  @field_class "w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm focus:border-purple-500 focus:outline-none"

  @impl true
  def mount(params, _session, %{assigns: %{current_scope: scope}} = socket) do
    case load(params, scope) do
      {:ok, show, episode, action} ->
        socket
        |> assign(show: show, episode: episode, action: action, episode_types: Episode.episode_types())
        |> assign_form(Podcasts.change_episode(episode))
        |> allow_upload(:audio, accept: ~w(.mp3), max_entries: 1, max_file_size: 200_000_000)
        |> then(&{:ok, &1})

      :error ->
        {:ok, socket |> put_flash(:error, gettext("Not found")) |> redirect(to: ~p"/studio/podcasts")}
    end
  end

  defp load(%{"show_id" => show_id, "id" => id}, scope) do
    with %Show{user_id: uid} = show when uid == scope.user.id <- Podcasts.get_show(show_id),
         %Episode{show_id: sid} = episode when sid == show.id <- Podcasts.get_episode(id) do
      {:ok, show, episode, :edit}
    else
      _ -> :error
    end
  end

  defp load(%{"show_id" => show_id}, scope) do
    case Podcasts.get_show(show_id) do
      %Show{user_id: uid} = show when uid == scope.user.id -> {:ok, show, %Episode{}, :new}
      _ -> :error
    end
  end

  @impl true
  def handle_event("validate", %{"episode" => params}, socket) do
    changeset = socket.assigns.episode |> Podcasts.change_episode(params) |> Map.put(:action, :validate)
    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :audio, ref)}
  end

  @impl true
  def handle_event("save", %{"episode" => params}, %{assigns: %{action: :edit, episode: episode}} = socket) do
    case Podcasts.update_episode(episode, params) do
      {:ok, _} ->
        {:noreply,
         socket |> put_flash(:info, gettext("Episode updated")) |> redirect(to: ~p"/studio/podcasts/#{socket.assigns.show.id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("save", %{"episode" => params}, %{assigns: %{action: :new, show: show}} = socket) do
    case consume_audio(socket) do
      {:ok, bytes} ->
        attrs = Map.take(params, ["title", "description", "season", "episode_number", "episode_type"])

        case Podcasts.upload_episode(show, attrs, bytes) do
          {:ok, _episode} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Episode uploaded — processing audio"))
             |> redirect(to: ~p"/studio/podcasts/#{show.id}")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, gettext("Upload failed"))}
        end

      :empty ->
        {:noreply, put_flash(socket, :error, gettext("Please choose an MP3 file"))}
    end
  end

  defp consume_audio(socket) do
    case uploaded_entries(socket, :audio) do
      {[_ | _], _} ->
        [bytes | _] =
          consume_uploaded_entries(socket, :audio, fn %{path: path}, _entry -> {:ok, File.read!(path)} end)

        {:ok, bytes}

      _ ->
        :empty
    end
  end

  defp assign_form(socket, changeset), do: assign(socket, form: to_form(changeset, as: "episode"))

  defp upload_error_message(:too_large), do: gettext("File is too large (max 200 MB)")
  defp upload_error_message(:not_accepted), do: gettext("Only MP3 files are allowed")
  defp upload_error_message(:too_many_files), do: gettext("Only one file can be uploaded")
  defp upload_error_message(_error), do: gettext("Upload error")

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :field_class, @field_class)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_page="podcasts">
      <div class="synthwave-bg min-h-screen text-white">
        <div class="max-w-2xl mx-auto px-6 py-12">
          <h1 class="text-2xl font-bold text-white mb-6">
            {if @action == :new, do: gettext("New episode"), else: gettext("Edit episode")}
          </h1>

          <.form
            for={@form}
            id="episode-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4 rounded-xl bg-gray-800/50 border border-gray-700 p-6"
          >
            <.input field={@form[:title]} type="text" label={gettext("Title")} class={@field_class} required />
            <.input field={@form[:description]} type="textarea" label={gettext("Show notes")} class={@field_class} />

            <div class="grid grid-cols-3 gap-3">
              <.input field={@form[:season]} type="number" label={gettext("Season")} min="1" class={@field_class} />
              <.input
                field={@form[:episode_number]}
                type="number"
                label={gettext("Episode number")}
                min="1"
                class={@field_class}
              />
              <.input
                field={@form[:episode_type]}
                type="select"
                label={gettext("Type")}
                options={@episode_types}
                class={@field_class}
              />
            </div>

            <div :if={@action == :new} phx-drop-target={@uploads.audio.ref}>
              <label class="block text-sm font-medium text-gray-300 mb-1">{gettext("Audio file (MP3)")}</label>
              <.live_file_input upload={@uploads.audio} class="text-sm text-gray-300" />
              <p class="text-xs text-gray-400 mt-1">{gettext("Duration is detected automatically after upload.")}</p>

              <div :for={entry <- @uploads.audio.entries} class="mt-2">
                <div class="flex items-center justify-between text-xs text-gray-300">
                  <span class="truncate">{entry.client_name}</span>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="text-red-400 hover:text-red-300 ml-2"
                    aria-label={gettext("Cancel")}
                  >
                    &times;
                  </button>
                </div>
                <div class="w-full bg-white/10 rounded h-2 mt-1">
                  <div class="bg-purple-500 h-2 rounded" style={"width: #{entry.progress}%"}></div>
                </div>
                <p :for={err <- upload_errors(@uploads.audio, entry)} class="text-xs text-red-400 mt-1">
                  {upload_error_message(err)}
                </p>
              </div>

              <p :for={err <- upload_errors(@uploads.audio)} class="text-xs text-red-400 mt-1">
                {upload_error_message(err)}
              </p>
            </div>

            <button
              type="submit"
              class="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg text-sm font-medium transition-colors"
            >
              {if @action == :new, do: gettext("Upload episode"), else: gettext("Save changes")}
            </button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
