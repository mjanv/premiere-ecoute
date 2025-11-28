defmodule PremiereEcouteWeb.Accounts.TermsAcceptanceLive do
  @moduledoc """
  Terms acceptance LiveView.

  Displays legal documents (privacy policy, cookies policy, terms of service) and collects user consent during Twitch authentication flow.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcouteWeb.Static.Legal

  @doc """
  Initializes terms acceptance page with legal documents.

  Validates pending authentication session, loads privacy policy, cookies policy, and terms of service documents, and initializes consent form state.
  """
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, %{"pending_twitch_auth" => pending_auth}, socket) do
    if pending_auth do
      socket
      |> assign(
        pending_auth: pending_auth,
        documents: %{privacy: Legal.document(:privacy), cookies: Legal.document(:cookies), terms: Legal.document(:terms)},
        consent_form: %{"privacy" => false, "cookies" => false, "terms" => false}
      )
      |> then(fn socket -> {:ok, socket} end)
    else
      socket
      |> put_flash(:error, "Authentication session expired")
      |> redirect(to: ~p"/")
      |> then(fn socket -> {:ok, socket} end)
    end
  end

  @doc """
  Handles user consent events for legal document acceptance.

  Validates complete consent acceptance and redirects to registration completion, or shows error if any required terms are not accepted, or handles registration decline.
  """
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event(
        "accept_terms",
        %{"consent" => %{"privacy" => "true", "cookies" => "true", "terms" => "true"} = consent},
        socket
      ) do
    socket
    |> redirect(to: ~p"/auth/twitch/complete?#{consent}")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("accept_terms", _params, socket) do
    socket
    |> put_flash(:error, "You must accept all required terms to continue")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("decline_terms", _params, socket) do
    socket
    |> put_flash(:info, "Registration declined")
    |> redirect(to: ~p"/")
    |> then(fn socket -> {:noreply, socket} end)
  end
end
