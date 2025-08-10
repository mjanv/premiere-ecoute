defmodule PremiereEcouteWeb.Accounts.TermsAcceptanceLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User.Consent
  alias PremiereEcouteWeb.Static.Legal
  alias PremiereEcoute.Accounts.Services.AccountRegistration

  def mount(_params, %{"pending_twitch_auth" => pending_auth}, socket) do
    if pending_auth do
      socket
      |> assign(
        pending_auth: pending_auth,
        documents: %{
          privacy: Legal.document(:privacy),
          cookies: Legal.document(:cookies),
          terms: Legal.document(:terms)
        },
        consent_form: %{
          "privacy" => false,
          "cookies" => false,
          "terms" => false
        },
        redirect_path: ~p"/home"
      )
      |> then(fn socket -> {:ok, socket} end)
    else
      socket
      |> put_flash(:error, "Authentication session expired")
      |> redirect(to: ~p"/")
      |> then(fn socket -> {:ok, socket} end)
    end
  end

  def handle_event("accept_terms", %{"consent" => consent}, socket) do
    if Enum.all?(["privacy", "cookies", "terms"], fn k -> consent[k] == "true" end) do
      case create_user_with_consent(socket.assigns.pending_auth, socket.assigns.documents, consent) do
        {:ok, user} ->
          socket
          |> put_flash(:info, "Terms accepted successfully. Welcome!")
          |> redirect(to: ~p"/auth/twitch/complete?user_id=#{user.id}")
          |> then(fn socket -> {:noreply, socket} end)

        {:error, reason} ->
          socket
          |> put_flash(:error, format_error(reason))
          |> then(fn socket -> {:noreply, socket} end)
      end
    else
      socket
      |> put_flash(:error, "You must accept all required terms to continue")
      |> assign(:consent_form, consent)
      |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event("decline_terms", _params, socket) do
    socket
    |> put_flash(:info, "Registration cancelled")
    |> redirect(to: ~p"/")
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp create_user_with_consent(pending_auth, documents, _consent_params) do
    # Auth data is already structured from TwitchApi.authorization_code/1
    auth_data = pending_auth.auth_data

    case AccountRegistration.register_twitch_user(auth_data) do
      {:ok, user} ->
        # Record all consents
        consent_results = [
          Consent.accept(user, documents.privacy),
          Consent.accept(user, documents.cookies),
          Consent.accept(user, documents.terms)
        ]

        # Check if all consents were recorded successfully
        case Enum.find(consent_results, fn result -> match?({:error, _}, result) end) do
          nil -> {:ok, user}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_error(changeset) when is_map(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&PremiereEcouteWeb.CoreComponents.translate_error/1)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp format_error(reason), do: "Registration failed: #{inspect(reason)}"
end
