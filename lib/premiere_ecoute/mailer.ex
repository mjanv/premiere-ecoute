defmodule PremiereEcoute.Mailer do
  @moduledoc false

  alias PremiereEcoute.Mailer.Email

  use Swoosh.Mailer, otp_app: :premiere_ecoute

  defmodule Behaviour do
    @moduledoc false

    @callback dispatch(map()) :: any()
  end

  @behaviour __MODULE__.Behaviour

  def impl, do: Application.get_env(:premiere_ecoute, :mailer, __MODULE__)

  def dispatch(event) do
    deliver(Email.from_event(event))
  end
end

defmodule PremiereEcoute.Mailer.Email do
  @moduledoc false

  import Swoosh.Email

  alias PremiereEcoute.Core.Event

  def from_event(event) do
    new()
    |> to({"Maxime Janvier", "maxime.janvier@gmail.com"})
    |> from({"Premiere Ecoute", "noreply@premiere-ecoute.onresend.com"})
    |> subject("#{Event.name(event)}")
    |> text_body("#{inspect(event)}")
  end
end
