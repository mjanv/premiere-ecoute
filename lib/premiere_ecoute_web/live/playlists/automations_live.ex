defmodule PremiereEcouteWeb.Playlists.AutomationsLive do
  @moduledoc "Index page — lists all automations for the current user."

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Automations

  defp format_dt(nil), do: "—"
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    automations = Automations.with_virtual_fields(user, Automations.list_automations(user))

    socket
    |> assign(:automations, automations)
    |> assign(:confirm_delete_id, nil)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("run_now", %{"id" => id}, socket) do
    case Automations.get_automation(String.to_integer(id)) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Automation not found"))}

      automation ->
        case Automations.run_now(automation) do
          {:ok, _job} ->
            {:noreply, put_flash(socket, :info, gettext("Run triggered for \"%{name}\"", name: automation.name))}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Failed to trigger run"))}
        end
    end
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :confirm_delete_id, String.to_integer(id))}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :confirm_delete_id, nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Automations.get_automation(String.to_integer(id)) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Automation not found"))}

      automation ->
        {:ok, _} = Automations.delete_automation(automation)
        user = socket.assigns.current_scope.user
        automations = Automations.with_virtual_fields(user, Automations.list_automations(user))

        socket
        |> assign(:automations, automations)
        |> assign(:confirm_delete_id, nil)
        |> put_flash(:info, gettext("Automation deleted"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_event("toggle_enabled", %{"id" => id}, socket) do
    case Automations.get_automation(String.to_integer(id)) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Automation not found"))}

      automation ->
        result =
          if automation.enabled,
            do: Automations.disable_automation(automation),
            else: Automations.enable_automation(automation)

        case result do
          {:ok, _} ->
            user = socket.assigns.current_scope.user
            automations = Automations.with_virtual_fields(user, Automations.list_automations(user))

            socket
            |> assign(:automations, automations)
            |> then(fn socket -> {:noreply, socket} end)

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Failed to update automation"))}
        end
    end
  end
end
