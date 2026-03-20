defmodule PremiereEcouteWeb.Playlists.AutomationLive do
  @moduledoc "Show page for a single automation — steps summary + live run history."

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Automations

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user

    case load_automation(id, user) do
      nil ->
        socket
        |> put_flash(:error, gettext("Automation not found"))
        |> push_navigate(to: ~p"/playlists/automations")
        |> then(fn socket -> {:ok, socket} end)

      automation ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "automation:#{automation.id}")
        end

        runs = Automations.list_runs(automation)

        socket
        |> assign(:automation, automation)
        |> assign(:runs, runs)
        |> assign(:expanded_run_id, nil)
        |> assign(:confirm_delete, false)
        |> then(fn socket -> {:ok, socket} end)
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("run_now", _params, socket) do
    case Automations.run_now(socket.assigns.automation) do
      {:ok, _job} ->
        {:noreply, put_flash(socket, :info, gettext("Run triggered"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to trigger run"))}
    end
  end

  @impl true
  def handle_event("toggle_enabled", _params, socket) do
    automation = socket.assigns.automation

    result =
      if automation.enabled,
        do: Automations.disable_automation(automation),
        else: Automations.enable_automation(automation)

    case result do
      {:ok, updated} ->
        {:noreply, assign(socket, :automation, updated)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update automation"))}
    end
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    {:noreply, assign(socket, :confirm_delete, true)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :confirm_delete, false)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Automations.delete_automation(socket.assigns.automation)

    socket
    |> put_flash(:info, gettext("Automation deleted"))
    |> push_navigate(to: ~p"/playlists/automations")
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("toggle_run", %{"run-id" => run_id_str}, socket) do
    run_id = String.to_integer(run_id_str)

    expanded =
      if socket.assigns.expanded_run_id == run_id, do: nil, else: run_id

    {:noreply, assign(socket, :expanded_run_id, expanded)}
  end

  @impl true
  def handle_info({:run_updated, run}, socket) do
    runs =
      Enum.map(socket.assigns.runs, fn r ->
        if r.id == run.id, do: run, else: r
      end)

    {:noreply, assign(socket, :runs, runs)}
  end

  @impl true
  def handle_info({:run_created, run}, socket) do
    {:noreply, assign(socket, :runs, [run | socket.assigns.runs])}
  end

  defp load_automation(id_str, user) do
    case Automations.get_automation(String.to_integer(id_str)) do
      %{user_id: uid} = automation when uid == user.id ->
        [automation] = Automations.with_virtual_fields(user, [automation])
        automation

      _ ->
        nil
    end
  end
end
