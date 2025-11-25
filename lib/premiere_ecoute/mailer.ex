defmodule PremiereEcoute.Mailer do
  @moduledoc """
  Email delivery service.

  Dispatch domain events as emails. Implementation can be swapped via the `:mailer` application config.
  """

  use Swoosh.Mailer, otp_app: :premiere_ecoute

  alias PremiereEcoute.Mailer.Email

  defmodule Behaviour do
    @moduledoc "Mailer callback specifications."

    @callback dispatch(map()) :: any()
  end

  @behaviour __MODULE__.Behaviour

  def impl, do: Application.get_env(:premiere_ecoute, :mailer, __MODULE__)
  def dispatch(event), do: deliver(Email.from_event(event))
end

defmodule PremiereEcoute.Mailer.Email do
  @moduledoc """
  Email.

  Emails can be converted from domain events to Swoosh emails.
  """

  import Swoosh.Email

  alias PremiereEcouteCore.Event

  def from_event(event) do
    new()
    |> to({"Maxime Janvier", "maxime.janvier@gmail.com"})
    |> from({"Premiere Ecoute", "hello@premiere-ecoute.fr"})
    |> subject("#{Event.name(event)}")
    |> text_body("#{inspect(event)}")
  end
end
