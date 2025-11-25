defmodule PremiereEcouteWeb.Accounts.TermsAcceptanceLive do
  @moduledoc """
  Terms acceptance LiveView.

  Displays legal documents (privacy policy, cookies policy, terms of service) and collects user consent during Twitch authentication flow.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcouteWeb.Static.Legal

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
