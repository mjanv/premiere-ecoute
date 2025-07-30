defmodule PremiereEcoute.Events.AccountCreated do
  @moduledoc false

  use PremiereEcoute.Core.Event, fields: [:twitch_user_id]
end

defmodule PremiereEcoute.Events.AccountDeleted do
  @moduledoc false

  use PremiereEcoute.Core.Event
end

defmodule PremiereEcoute.Events.ChannelFollowed do
  @moduledoc false

  use PremiereEcoute.Core.Event, fields: [:streamer_id]
end

defmodule PremiereEcoute.Events.ChannelUnfollowed do
  @moduledoc false

  use PremiereEcoute.Core.Event, fields: [:streamer_id]
end
