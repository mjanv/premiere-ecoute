defmodule PremiereEcoute.Events.PodcastShowPublished do
  @moduledoc """
  Event - Podcast show published (feed made discoverable). `id` is the show id.
  """

  @type t :: %__MODULE__{id: integer() | nil}

  use PremiereEcouteCore.Event
end

defmodule PremiereEcoute.Events.PodcastEpisodePublished do
  @moduledoc """
  Event - Podcast episode published into a show feed. `id` is the episode id.
  """

  @type t :: %__MODULE__{id: integer() | nil, show_id: integer() | nil}

  use PremiereEcouteCore.Event, fields: [:show_id]
end

defmodule PremiereEcoute.Events.PodcastEpisodeDownloaded do
  @moduledoc """
  Event - Podcast episode audio downloaded/streamed, tagged by source (:web or :feed).
  `id` is the episode id.
  """

  @type t :: %__MODULE__{id: integer() | nil, source: atom() | nil, ip: String.t() | nil, user_agent: String.t() | nil}

  use PremiereEcouteCore.Event, fields: [:source, :ip, :user_agent]
end
