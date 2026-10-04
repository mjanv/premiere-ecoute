defmodule PremiereEcouteWeb.Sessions.Components.ReplaySlots do
  @moduledoc """
  The replays of a session in the My Sessions list.

  One row per configured replay: its status, the video when it is found, and the actions that apply to its
  status. A replay can be linked by hand with an inline form.
  """

  use PremiereEcouteWeb, :html

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Services.ReplayVideo

  attr :session, ListeningSession, required: true
  attr :pasting, :string, default: nil, doc: "id of the replay whose link form is open"
  attr :error, :string, default: nil, doc: "error of the link form"
  attr :checking, :list, default: [], doc: "ids of the replays being checked now"

  @spec replay_slots(map()) :: Phoenix.LiveView.Rendered.t()
  def replay_slots(assigns) do
    assigns = assign(assigns, :slots, ReplayVideo.slots(assigns.session))

    ~H"""
    <div :if={@slots != []} id={"replays-#{@session.id}"} class="border-t border-white/10 px-6 py-3 space-y-2">
      <div :for={slot <- @slots} id={"replay-#{@session.id}-#{slot["replay_id"]}"} class="space-y-2">
        <% status = ReplayVideo.status(slot) %>
        <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
          <.status_badge variant={badge(status).variant} icon={badge(status).icon} size="xs">
            {badge(status).text}
          </.status_badge>
          <span class="font-medium text-white text-sm">{slot["label"]}</span>
          <span :if={badge(status).detail} class="text-xs text-white/60">{badge(status).detail}</span>
          <a
            :if={slot["url"]}
            href={slot["url"]}
            target="_blank"
            rel="noopener"
            class="text-sm text-purple-300 hover:text-purple-200 truncate"
          >
            {title(slot)}
          </a>
          <span :if={slot["title"] && source(slot)} class="text-xs text-white/60">{source(slot)}</span>
          <div class="ml-auto flex items-center gap-1">
            <.button
              :for={{action, label} <- actions(status)}
              type="button"
              variant="ghost"
              size="xs"
              phx-click="replay_action"
              phx-value-action={action}
              phx-value-session_id={@session.id}
              phx-value-replay_id={slot["replay_id"]}
              disabled={action == "check" and slot["replay_id"] in @checking}
            >
              {if action == "check" and slot["replay_id"] in @checking, do: gettext("Checking..."), else: label}
            </.button>
          </div>
        </div>

        <form :if={@pasting == slot["replay_id"]} phx-submit="attach_replay" class="flex flex-wrap items-center gap-2">
          <input type="hidden" name="session_id" value={@session.id} />
          <input type="hidden" name="replay_id" value={slot["replay_id"]} />
          <input
            type="url"
            name="url"
            required
            placeholder="https://www.youtube.com/watch?v=..."
            class="flex-1 min-w-0 bg-black/40 border border-white/20 rounded-lg px-3 py-1.5 text-white text-sm placeholder-slate-600 focus:outline-none focus:border-purple-400"
          />
          <.button type="submit" variant="primary" size="xs">{gettext("Link")}</.button>
          <.button
            type="button"
            variant="ghost"
            size="xs"
            phx-click="replay_action"
            phx-value-action="cancel"
            phx-value-session_id={@session.id}
            phx-value-replay_id={slot["replay_id"]}
          >
            {gettext("Cancel")}
          </.button>
        </form>
        <p :if={@pasting == slot["replay_id"] && @error} class="text-xs text-red-400">{@error}</p>
      </div>
    </div>
    """
  end

  defp badge("found"), do: %{variant: "success", icon: "hero-check-circle", text: gettext("Found"), detail: nil}

  defp badge("pending"), do: %{variant: "info", icon: "hero-clock", text: gettext("Missing"), detail: nil}

  defp badge("exhausted"),
    do: %{
      variant: "warning",
      icon: "hero-exclamation-triangle",
      text: gettext("Missing"),
      detail: gettext("not found after all checks")
    }

  defp badge("rejected"),
    do: %{variant: "warning", icon: "hero-x-circle", text: gettext("Missing"), detail: gettext("match rejected")}

  defp badge("skipped"), do: %{variant: "secondary", icon: "hero-minus-circle", text: gettext("Skipped"), detail: nil}

  defp actions("found"), do: [{"unmark", gettext("Unmark")}]
  defp actions("pending"), do: [{"check", gettext("Check now")}, {"paste", gettext("Link")}, {"skip", gettext("Skip")}]
  defp actions("exhausted"), do: [{"retry", gettext("Retry")}, {"paste", gettext("Link")}, {"skip", gettext("Skip")}]
  defp actions("rejected"), do: [{"paste", gettext("Link")}, {"skip", gettext("Skip")}]
  defp actions("skipped"), do: [{"unskip", gettext("Unskip")}]

  defp title(%{"title" => title}) when is_binary(title) and title != "", do: title
  defp title(slot), do: source(slot)

  defp source(%{"channel_title" => title}) when is_binary(title) and title != "", do: title

  defp source(%{"url" => url}) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> String.replace_prefix(host, "www.", "")
      _ -> url
    end
  end
end
