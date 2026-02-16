defmodule PremiereEcoute.Apis.MusicProvider do
  @moduledoc false

  @callback vital_fun() :: any
  @optional_callbacks vital_fun: 0
end
