defmodule PremiereEcoute.Events.AccountCreated do
  @moduledoc false

  use PremiereEcoute.Core.Event
end

defmodule PremiereEcoute.Events.AccountAssociated do
  @moduledoc false

  use PremiereEcoute.Core.Event, fields: [:provider, :user_id]
end

defmodule PremiereEcoute.Events.AccountDeleted do
  @moduledoc false

  use PremiereEcoute.Core.Event
end

defmodule PremiereEcoute.Events.PersonalDataRequested do
  @moduledoc false

  use PremiereEcoute.Core.Event, fields: [:result]
end

defmodule PremiereEcoute.Events.ChannelFollowed do
  @moduledoc false

  use PremiereEcoute.Core.Event, fields: [:streamer_id]
end

defmodule PremiereEcoute.Events.ChannelUnfollowed do
  @moduledoc false

  use PremiereEcoute.Core.Event, fields: [:streamer_id]
end
