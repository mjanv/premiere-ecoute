defmodule PremiereEcoute.Mailer do
  @moduledoc false

  alias PremiereEcoute.Mailer.Email

  use Swoosh.Mailer, otp_app: :premiere_ecoute

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
