defmodule PremiereEcoute.Events.AccountCreated do
  @moduledoc """
  Event - Account created.
  """

  use PremiereEcouteCore.Event
end

defmodule PremiereEcoute.Events.ConsentGiven do
  @moduledoc """
  Event - User consent given for legal document.
  """

  use PremiereEcouteCore.Event, fields: [:document, :version, :accepted]
end

defmodule PremiereEcoute.Events.AccountAssociated do
  @moduledoc """
  Event - External account associated with user.
  """

  use PremiereEcouteCore.Event, fields: [:provider, :user_id]
end

defmodule PremiereEcoute.Events.AccountDeleted do
  @moduledoc """
  Event - Account deleted.
  """

  use PremiereEcouteCore.Event
end

defmodule PremiereEcoute.Events.PersonalDataRequested do
  @moduledoc """
  Event - Personal data export requested.
  """

  use PremiereEcouteCore.Event, fields: [:result]
end

defmodule PremiereEcoute.Events.ChannelFollowed do
  @moduledoc """
  Event - Twitch channel followed.
  """

  use PremiereEcouteCore.Event, fields: [:streamer_id]
end

defmodule PremiereEcoute.Events.ChannelUnfollowed do
  @moduledoc """
  Event - Twitch channel unfollowed.
  """

  use PremiereEcouteCore.Event, fields: [:streamer_id]
end

defmodule PremiereEcoute.Events.TrackLiked do
  @moduledoc """
  Event - Track liked on streaming platform.
  """

  use PremiereEcouteCore.Event, fields: [:provider, :user_id, :track_id]
end
