defmodule PremiereEcouteWeb.Playlists.Automations.FormLive do
  @moduledoc "Create (:new) and edit (:edit) form for automations."

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Automations
  alias PremiereEcoute.Discography

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket
    |> assign(:library_playlists, Discography.LibraryPlaylist.all(where: [user_id: user.id]))
    |> assign(:action_registry, Automations.action_registry())
    |> assign(:show_add_step_modal, false)
    |> assign(:errors, %{})
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(%{"id" => id}, _url, %{assigns: %{live_action: :edit}} = socket) do
    user = socket.assigns.current_scope.user

    case Automations.get_automation(user, String.to_integer(id)) do
      nil ->
        socket
        |> put_flash(:error, gettext("Automation not found"))
        |> push_navigate(to: ~p"/playlists/automations")
        |> then(fn socket -> {:noreply, socket} end)

      automation ->
        socket
        |> assign(:automation, automation)
        |> assign(:steps, automation.steps)
        |> assign(:schedule, to_string(automation.schedule))
        |> assign(:form_data, %{
          "name" => automation.name,
          "description" => automation.description || "",
          "cron_expression" => automation.cron_expression || "",
          "scheduled_date" => format_scheduled_date(automation.scheduled_at),
          "scheduled_hour" => format_scheduled_hour(automation.scheduled_at),
          "scheduled_minute" => format_scheduled_minute(automation.scheduled_at)
        })
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_params(_params, _url, %{assigns: %{live_action: :new}} = socket) do
    socket
    |> assign(:automation, nil)
    |> assign(:steps, [])
    |> assign(:schedule, "manual")
    |> assign(:form_data, %{
      "name" => "",
      "description" => "",
      "cron_expression" => "",
      "scheduled_date" => "",
      "scheduled_hour" => "09",
      "scheduled_minute" => "00"
    })
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("change", params, socket) do
    form_data =
      socket.assigns.form_data
      |> Map.merge(Map.take(params, ["name", "description", "cron_expression"]))

    steps =
      case params["steps"] do
        nil ->
          socket.assigns.steps

        steps_params ->
          socket.assigns.steps
          |> Enum.with_index()
          |> Enum.map(fn {step, idx} ->
            config = get_in(steps_params, [to_string(idx), "config"]) || step["config"]
            Map.put(step, "config", config)
          end)
      end

    socket
    |> assign(:form_data, form_data)
    |> assign(:steps, steps)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("change_schedule", %{"schedule" => type}, socket) do
    {:noreply, assign(socket, :schedule, type)}
  end

  @impl true
  def handle_event("ignore", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_add_step", _params, socket) do
    {:noreply, assign(socket, :show_add_step_modal, true)}
  end

  @impl true
  def handle_event("hide_add_step", _params, socket) do
    {:noreply, assign(socket, :show_add_step_modal, false)}
  end

  @impl true
  def handle_event("add_step", %{"action_type" => action_type}, socket) do
    new_position = length(socket.assigns.steps) + 1

    new_step = %{
      "position" => new_position,
      "action_type" => action_type,
      "config" => %{}
    }

    socket
    |> assign(:steps, socket.assigns.steps ++ [new_step])
    |> assign(:show_add_step_modal, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("remove_step", %{"index" => index_str}, socket) do
    idx = String.to_integer(index_str)
    steps = List.delete_at(socket.assigns.steps, idx)
    steps = reposition(steps)
    {:noreply, assign(socket, :steps, steps)}
  end

  @impl true
  def handle_event("move_step_up", %{"index" => index_str}, socket) do
    idx = String.to_integer(index_str)

    steps =
      socket.assigns.steps
      |> swap(idx - 1, idx)
      |> reposition()

    {:noreply, assign(socket, :steps, steps)}
  end

  @impl true
  def handle_event("move_step_down", %{"index" => index_str}, socket) do
    idx = String.to_integer(index_str)

    steps =
      socket.assigns.steps
      |> swap(idx, idx + 1)
      |> reposition()

    {:noreply, assign(socket, :steps, steps)}
  end

  @impl true
  def handle_event("save", params, socket) do
    user = socket.assigns.current_scope.user
    steps = socket.assigns.steps

    attrs =
      socket.assigns.form_data
      |> Map.take(["name", "description", "cron_expression"])
      |> Map.put(
        "scheduled_at",
        combine_scheduled_at(params["scheduled_date"], params["scheduled_hour"], params["scheduled_minute"])
      )
      |> Map.put("schedule", socket.assigns.schedule)
      |> Map.put("steps", steps)

    result =
      case socket.assigns.live_action do
        :new -> Automations.create_automation(user, attrs)
        :edit -> Automations.update_automation(socket.assigns.automation, attrs)
      end

    case result do
      {:ok, automation} ->
        socket
        |> put_flash(:info, gettext("Automation saved"))
        |> push_navigate(to: ~p"/playlists/automations/#{automation.id}")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, changeset} ->
        errors = changeset_errors(changeset)

        socket
        |> assign(:errors, errors)
        |> put_flash(:error, gettext("Please fix the errors below"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_event("save_and_run", _params, socket) do
    user = socket.assigns.current_scope.user
    steps = socket.assigns.steps

    attrs =
      socket.assigns.form_data
      |> Map.take(["name", "description", "cron_expression", "scheduled_at"])
      |> Map.put("schedule", socket.assigns.schedule)
      |> Map.put("steps", steps)

    result =
      case socket.assigns.live_action do
        :new -> Automations.create_automation(user, attrs)
        :edit -> Automations.update_automation(socket.assigns.automation, attrs)
      end

    case result do
      {:ok, automation} ->
        Automations.schedule(automation)

        socket
        |> put_flash(:info, gettext("Automation saved and run triggered"))
        |> push_navigate(to: ~p"/playlists/automations/#{automation.id}")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, changeset} ->
        errors = changeset_errors(changeset)

        socket
        |> assign(:errors, errors)
        |> put_flash(:error, gettext("Please fix the errors below"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp reposition(steps) do
    steps
    |> Enum.with_index(1)
    |> Enum.map(fn {step, pos} -> Map.put(step, "position", pos) end)
  end

  defp swap(list, i, j) when i >= 0 and j < length(list) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)

    list
    |> List.replace_at(i, b)
    |> List.replace_at(j, a)
  end

  defp swap(list, _i, _j), do: list

  defp format_scheduled_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
  defp format_scheduled_date(_), do: ""

  defp format_scheduled_hour(%DateTime{} = dt), do: String.pad_leading(to_string(dt.hour), 2, "0")
  defp format_scheduled_hour(_), do: "09"

  defp format_scheduled_minute(%DateTime{} = dt), do: String.pad_leading(to_string(dt.minute), 2, "0")
  defp format_scheduled_minute(_), do: "00"

  defp combine_scheduled_at(date, hour, minute) when is_binary(date) and date != "" do
    "#{date}T#{hour || "00"}:#{minute || "00"}"
  end

  defp combine_scheduled_at(_, _, _), do: nil

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
