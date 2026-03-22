defmodule PremiereEcouteCore.Channel do
  @moduledoc """
  Tracks all PubSub channels declared with ~h at compile time.

  Usage:
    use PremiereEcouteCore.Channel

    @channel ~h"user:{id}"
  """

  defmacro __using__(_opts) do
    quote do
      import PremiereEcouteCore.Channel, only: [sigil_h: 2]
      Module.register_attribute(__MODULE__, :channels, accumulate: true)
      @before_compile PremiereEcouteCore.Channel
    end
  end

  defmacro __before_compile__(env) do
    channels = Module.get_attribute(env.module, :channels)

    quote do
      def __channels__, do: unquote(channels)
    end
  end

  defmacro sigil_h({:<<>>, _meta, parts}, _args) do
    template =
      Enum.map_join(parts, fn
        string when is_binary(string) ->
          string

        {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [_inner]}, {:binary, _, _}]} ->
          "_"
      end)

    # #{Macro.to_string(inner)}

    Module.put_attribute(__CALLER__.module, :channels, template)

    quote do: <<unquote_splicing(parts)>>
  end
end

defmodule PremiereEcoute.Prout do
  @moduledoc false

  use PremiereEcouteCore.Channel

  def a(id), do: ~h"artist:#{id}"
  def b(artist), do: ~h"user:#{artist.meta.id}"
end

defmodule PremiereEcouteCore.ChannelRegistry do
  @moduledoc false

  def all do
    :application.get_key(:premiere_ecoute, :modules)
    |> elem(1)
    |> Enum.flat_map(fn mod ->
      if function_exported?(mod, :__channels__, 0) do
        mod.__channels__()
      else
        []
      end
    end)
  end
end
