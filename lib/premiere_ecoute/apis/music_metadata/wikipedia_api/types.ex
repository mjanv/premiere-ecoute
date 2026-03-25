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

  defmodule Section do
    @moduledoc false

    @type t() :: %__MODULE__{
            number: String.t(),
            title: String.t(),
            level: pos_integer(),
            anchor: String.t()
          }

    defstruct [:number, :title, :level, :anchor]
  end

  defmodule TableOfContents do
    @moduledoc false

    @type t() :: %__MODULE__{
            title: String.t(),
            page_id: pos_integer(),
            sections: [Section.t()]
          }

    defstruct [:title, :page_id, :sections]
  end
end
