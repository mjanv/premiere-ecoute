defmodule PremiereEcouteWeb.Gettext do
  @moduledoc false

  use Gettext.Backend, otp_app: :premiere_ecoute

  def gettext(msgid) do
    Gettext.gettext(__MODULE__, msgid)
  end
end
