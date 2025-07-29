defmodule AccountCreated do
  @moduledoc false

  defstruct [:id, :twitch_user_id]
end

defmodule AccountDeleted do
  @moduledoc false

  defstruct [:id]
end

defmodule ChannelFollowed do
  @moduledoc false

  defstruct [:id, :streamer_id]
end

defmodule ChannelUnfollowed do
  @moduledoc false

  defstruct [:id, :streamer_id]
end
