defmodule PremiereEcoute.Sessions.Formats.Xmeml do
  @moduledoc false
  
  
  alias PremiereEcoute.Sessions.ListeningSession
  
  def build(%ListeningSession{} = session, _opts) do
    session
  end
end