defmodule PremiereEcoute.Events.AccountCreated do
  @moduledoc """
  Event - Account created.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil
        }

  use PremiereEcouteCore.Event
end

defmodule PremiereEcoute.Events.ConsentGiven do
  @moduledoc """
  Event - User consent given for legal document.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          document: term(),
          version: term(),
          accepted: term()
        }

  use PremiereEcouteCore.Event, fields: [:document, :version, :accepted]
end

defmodule PremiereEcoute.Events.AccountAssociated do
  @moduledoc """
  Event - External account associated with user.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          provider: term(),
          user_id: term()
        }

  use PremiereEcouteCore.Event, fields: [:provider, :user_id]
end

defmodule PremiereEcoute.Events.AccountDeleted do
  @moduledoc """
  Event - Account deleted.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil
        }

  use PremiereEcouteCore.Event
end

defmodule PremiereEcoute.Events.PersonalDataRequested do
  @moduledoc """
  Event - Personal data export requested.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          result: term()
        }

  use PremiereEcouteCore.Event, fields: [:result]
end

defmodule PremiereEcoute.Events.ChannelFollowed do
  @moduledoc """
  Event - Twitch channel followed.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          streamer_id: term()
        }

  use PremiereEcouteCore.Event, fields: [:streamer_id]
end

defmodule PremiereEcoute.Events.ChannelUnfollowed do
  @moduledoc """
  Event - Twitch channel unfollowed.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          streamer_id: term()
        }

  use PremiereEcouteCore.Event, fields: [:streamer_id]
end

defmodule PremiereEcoute.Events.TrackLiked do
  @moduledoc """
  Event - Track liked on streaming platform.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          provider: term(),
          user_id: term(),
          track_id: term()
        }

  use PremiereEcouteCore.Event, fields: [:provider, :user_id, :track_id]
end
