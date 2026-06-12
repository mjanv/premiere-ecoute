defmodule PremiereEcoute.Events.ShowCreated do
  @moduledoc """
  Event - Podcast show created. `id` is the show id; stream `podcasts_show-<id>`.
  """

  @type t :: %__MODULE__{id: integer() | nil, user_id: integer() | nil}

  use PremiereEcouteCore.Event, fields: [:user_id]
end

defmodule PremiereEcoute.Events.ShowPublished do
  @moduledoc """
  Event - Podcast show published (feed made discoverable). `id` is the show id.
  """

  @type t :: %__MODULE__{id: integer() | nil}

  use PremiereEcouteCore.Event
end

defmodule PremiereEcoute.Events.EpisodeUploaded do
  @moduledoc """
  Event - Podcast episode audio uploaded, pending processing. `id` is the episode id.
  """

  @type t :: %__MODULE__{id: integer() | nil, show_id: integer() | nil}

  use PremiereEcouteCore.Event, fields: [:show_id]
end

defmodule PremiereEcoute.Events.EpisodeProcessed do
  @moduledoc """
  Event - Podcast episode processed (duration and byte size extracted). `id` is the episode id.
  """

  @type t :: %__MODULE__{id: integer() | nil, duration_seconds: integer() | nil, audio_byte_size: integer() | nil}

  use PremiereEcouteCore.Event, fields: [:duration_seconds, :audio_byte_size]
end

defmodule PremiereEcoute.Events.EpisodePublished do
  @moduledoc """
  Event - Podcast episode published into a show feed. `id` is the episode id.
  """

  @type t :: %__MODULE__{id: integer() | nil, show_id: integer() | nil}

  use PremiereEcouteCore.Event, fields: [:show_id]
end

defmodule PremiereEcoute.Events.EpisodeDownloaded do
  @moduledoc """
  Event - Podcast episode audio downloaded/streamed, tagged by source (:web or :feed).
  `id` is the episode id.
  """

  @type t :: %__MODULE__{id: integer() | nil, source: atom() | nil, ip: String.t() | nil, user_agent: String.t() | nil}

  use PremiereEcouteCore.Event, fields: [:source, :ip, :user_agent]
end
