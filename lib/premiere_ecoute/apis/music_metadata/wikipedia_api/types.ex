defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types do
  @moduledoc false

  defmodule Page do
    @moduledoc false

    @type t() :: %__MODULE__{
            id: String.t(),
            title: String.t(),
            url: String.t()
          }

    defstruct [:id, :title, :url]
  end

  defmodule Summary do
    @moduledoc false

    @type t() :: %{
            title: String.t(),
            extract: String.t(),
            thumbnail_url: String.t() | nil,
            page_url: String.t() | nil
          }

    defstruct [:title, :extract, :thumbnail_url, :page_url]
  end
end
