defmodule AccountCreated do
  @moduledoc false

  defstruct [:id, :twitch_user_id]
end

defmodule AccountDeleted do
  @moduledoc false

  defstruct [:id]
end
