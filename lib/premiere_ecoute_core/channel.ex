defmodule PremiereEcouteCore.Channel do
  @moduledoc """
  Tracks all PubSub channels declared with ~h at compile time.

  Usage:
    use PremiereEcouteCore.Channel

    @channel ~h"user:{id}"
  """

  @doc """
  Registers the `~h` sigil and tracks the channels declared in the module.
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      import PremiereEcouteCore.Channel, only: [sigil_h: 2]
      Module.register_attribute(__MODULE__, :channels, accumulate: true, persist: true)

      @doc "Returns the templates of the channels declared in this module."
      @spec __channels__() :: [String.t()]
      def __channels__ do
        __MODULE__.__info__(:attributes) |> Keyword.get_values(:channels) |> Enum.concat() |> Enum.reverse()
      end
    end
  end

  @doc """
  Builds a channel name and records its template, interpolations being replaced by `_`.
  """
  @spec sigil_h(Macro.t(), charlist()) :: Macro.t()
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

  @doc """
  Returns the artist channel name.
  """
  @spec a(term()) :: String.t()
  def a(id), do: ~h"artist:#{id}"

  @doc """
  Returns the user channel name of an artist.
  """
  @spec b(map()) :: String.t()
  def b(artist), do: ~h"user:#{artist.meta.id}"
end

defmodule PremiereEcouteCore.ChannelRegistry do
  @moduledoc false

  @doc """
  Returns the templates of all channels declared in the application.
  """
  @spec all() :: [String.t()]
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
