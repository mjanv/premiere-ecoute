defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Facade do
  @moduledoc false

  @api PremiereEcoute.Apis.MusicProvider.SpotifyApi
  @gateway Module.concat([@api, Gateway])

  for {name, arity} <- @api.__info__(:functions) do
    args = Macro.generate_arguments(arity, __MODULE__)

    def unquote(name)(unquote_splicing(args)) do
      @gateway.call(@api, unquote(name), [unquote_splicing(args)])
    end
  end
end
