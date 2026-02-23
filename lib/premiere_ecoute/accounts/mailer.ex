defmodule PremiereEcoute.Accounts.Mailer do
  @moduledoc """
  Email delivery service.

  Dispatch domain events as emails. Implementation can be swapped via the `:mailer` application config.
  """

  use Swoosh.Mailer, otp_app: :premiere_ecoute

  alias PremiereEcoute.Accounts.Mailer.Email

  defmodule Behaviour do
    @moduledoc "Mailer callback specifications."

    @callback dispatch(map()) :: any()
  end

  @behaviour __MODULE__.Behaviour

  @doc "Returns configured mailer implementation module"
  @spec impl :: module()
  def impl, do: Application.get_env(:premiere_ecoute, :mailer, __MODULE__)

  @doc "Returns the list of implemented behaviours"
  @spec behaviours() :: [module()]
  def behaviours, do: [__MODULE__.Behaviour]

  @doc """
  Dispatches domain event as email.

  Converts event to email and delivers via configured mailer implementation.
  """
  @spec dispatch(map()) :: any()
  def dispatch(event), do: deliver(Email.from_event(event))
end

defmodule PremiereEcoute.Accounts.Mailer.Email do
  @moduledoc """
  Email.

  Emails can be converted from domain events to Swoosh emails.
  """

  import Swoosh.Email

  alias PremiereEcouteCore.Event

  @doc """
  Converts domain event to Swoosh email.

  Creates email with event name as subject and event inspection as body for debugging purposes.
  """
  @spec from_event(map()) :: Swoosh.Email.t()
  def from_event(event) do
    new()
    |> to({"Maxime Janvier", "maxime.janvier@gmail.com"})
    |> from({"Premiere Ecoute", "hello@premiere-ecoute.fr"})
    |> subject("#{Event.name(event)}")
    |> text_body("#{inspect(event)}")
  end
end
