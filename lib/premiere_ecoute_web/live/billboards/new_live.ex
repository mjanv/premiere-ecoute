defmodule PremiereEcouteWeb.Billboards.NewLive do
  @moduledoc """
  Billboard creation LiveView.

  Provides form to create new billboards with title validation, real-time form validation feedback, and redirects to created billboard on successful submission.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Billboard

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_form(Billboards.change_billboard(%Billboard{}))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("validate", %{"billboard" => billboard_params}, socket) do
    changeset =
      %Billboard{}
      |> Billboards.change_billboard(billboard_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"billboard" => billboard}, %{assigns: %{current_scope: current_scope}} = socket) do
    %Billboard{title: billboard["title"], user_id: current_scope.user.id}
    |> Billboards.create_billboard()
    |> case do
      {:ok, billboard} ->
        socket
        |> put_flash(:info, gettext("Billboard created successfully!"))
        |> redirect(to: ~p"/billboards/#{billboard.billboard_id}")
        |> then(fn socket -> {:noreply, socket} end)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "billboard"))
  end
end
