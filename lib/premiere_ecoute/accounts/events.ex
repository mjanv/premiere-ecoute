defmodule AccountCreated do
  @moduledoc false

  use PremiereEcoute.Core.Event, fields: [:twitch_user_id]
end

defmodule AccountDeleted do
  @moduledoc false

  use PremiereEcoute.Core.Event
end

defmodule ChannelFollowed do
  @moduledoc false

  use PremiereEcoute.Core.Event, fields: [:streamer_id]
end

defmodule ChannelUnfollowed do
  @moduledoc false

  use PremiereEcoute.Core.Event, fields: [:streamer_id]
end
