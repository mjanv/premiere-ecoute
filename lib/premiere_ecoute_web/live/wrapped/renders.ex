defmodule PremiereEcouteWeb.Wrapped.Renders do
  @moduledoc """
  The renders of a Wrapped: the different ways the same stored recap can be played.

  A recap is data; a render is how the browser plays it: a function component for the markup and a JS hook for the playback. The first render is the default one.

  ## Adding a render

  1. Write its hook in its own folder, `assets/js/wrapped/renders/<id>/`, and register it in `assets/js/wrapped/index.js`. The classic render has one file per card in `cards/`, picked from the `data-type` of each card section; `assets/js/wrapped/sound.js` is shared by every render.
  2. Scope its styles under `.wrapped[data-render="<id>"]` in `assets/css/components/`.
  3. Add a `%Render{}` to `built_in/0`. The pixel render shows the other way to build one: `PixelStories` sends the cards as data and its hook draws everything on a canvas.

  Step 3 in short: Reuse `Stories.stories/1` when only the JS and the CSS differ, or point `component` to another function component taking the same assigns.

  ## Choosing a render

    * `?render=<id>` picks one for a visit, where the page allows it (the dev preview, the admin replay, and admins anywhere).
    * The feature flag `wrapped_render_<id>` assigns a render to the users it is enabled for: `FeatureFlag.enable(:wrapped_render_shader, for_actor: user)`.
    * Anyone else gets the default render.
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcouteCore.FeatureFlag
  alias PremiereEcouteWeb.Wrapped.PixelStories
  alias PremiereEcouteWeb.Wrapped.Stories

  defmodule Render do
    @moduledoc """
    One way to play a Wrapped: `hook` is the JS hook driving the playback, `component` the function component rendering the markup.
    """

    @enforce_keys [:id, :name, :hook, :component]
    defstruct [:id, :name, :hook, :component]

    @type t :: %__MODULE__{
            id: atom(),
            name: String.t(),
            hook: String.t(),
            component: (map() -> Phoenix.LiveView.Rendered.t())
          }
  end

  @doc "Lists the renders, the default one first."
  @spec all() :: [Render.t()]
  def all, do: Application.get_env(:premiere_ecoute, __MODULE__, [])[:renders] || built_in()

  @doc "The renders shipped with the application."
  @spec built_in() :: [Render.t()]
  def built_in do
    [
      %Render{id: :classic, name: "Classic", hook: "WrappedPlayer", component: &Stories.stories/1},
      %Render{id: :pixel, name: "Pixel", hook: "WrappedPlayerPixel", component: &PixelStories.stories/1}
    ]
  end

  @doc "The render played when nothing else is chosen."
  @spec default([Render.t()]) :: Render.t()
  def default(renders \\ all()), do: hd(renders)

  @doc "Finds a render from its id, given as an atom or as the text of a URL parameter."
  @spec get(atom() | String.t() | nil, [Render.t()]) :: Render.t() | nil
  def get(id, renders \\ all())
  def get(nil, _renders), do: nil
  def get(id, renders), do: Enum.find(renders, &(Atom.to_string(&1.id) == to_string(id)))

  @doc "The feature flag assigning a render to the users it is enabled for."
  @spec flag(Render.t()) :: atom()
  def flag(%Render{id: id}), do: :"wrapped_render_#{id}"

  @doc "The render assigned to a user: the first one, after the default, whose flag is enabled for them."
  @spec assigned(User.t() | nil, [Render.t()]) :: Render.t()
  def assigned(user, renders \\ all())
  def assigned(nil, renders), do: default(renders)

  def assigned(%User{} = user, [default | others]),
    do: Enum.find(others, default, &FeatureFlag.enabled?(flag(&1), for: user))

  @doc """
  Chooses the render of a visit.

  `param` is the `render` URL parameter and only counts with `override?: true`; an unknown id is ignored. Otherwise the render assigned to `user` is played.
  """
  @spec select(keyword(), [Render.t()]) :: Render.t()
  def select(opts, renders \\ all()) do
    override = if opts[:override?], do: get(opts[:param], renders)

    override || assigned(opts[:user], renders)
  end

  @doc "Renders a Wrapped with the given render. Takes the assigns of `Stories.stories/1`."
  @spec player(map()) :: Phoenix.LiveView.Rendered.t()
  def player(%{render: %Render{component: component}} = assigns), do: component.(assigns)
end
