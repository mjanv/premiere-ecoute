defmodule UserCreated do
  @moduledoc false

  @derive Jason.Encoder
  defstruct [:id]
end

defmodule UserNotCreated do
  @moduledoc false

  @derive Jason.Encoder
  defstruct [:id]
end
