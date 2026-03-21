defmodule PremiereEcoute.Playlists.Automations.Action do
  @moduledoc """
  DSL and behaviour for automation action implementations.

  ## Usage

      defmodule MyAction do
        use PremiereEcoute.Playlists.Automations.Action

        name "my_action"
        description "Does something useful."

        inputs do
          input :playlist_id, :playlist_id, required: true, description: "Target playlist"
          input :name, :string, required: true, description: "New name"
          input :public, :boolean, required: false, description: "Make it public"
        end

        outputs do
          output :track_count, :integer, description: "Number of tracks processed"
        end

        def execute(config, context, scope) do
          # ...
        end
      end

  ## Input types

    - `:playlist_id`      — single Spotify playlist ID string (supports `$created_playlist_id` context ref)
    - `:playlist_id_list` — list of Spotify playlist ID strings
    - `:string`           — arbitrary string (supports Template placeholders)
    - `:boolean`          — boolean flag

  ## Auto-generated callbacks

  `use Action` generates `id/0`, `validate/1`, `meta/0` from the DSL declarations.
  Required inputs produce presence-validation; optional inputs are skipped.
  `execute/3` must always be implemented manually.
  `validate/1` can be overridden for actions with custom validation rules.
  """

  alias PremiereEcoute.Accounts.Scope

  @type input_type :: :playlist_id | :playlist_id_list | :string | :boolean
  @type output_type :: :integer | :string | :playlist_id | :boolean

  @type input_spec :: %{
          key: String.t(),
          type: input_type(),
          required: boolean(),
          description: String.t()
        }

  @type output_spec :: %{
          key: String.t(),
          type: output_type(),
          description: String.t()
        }

  @type meta :: %{
          id: String.t(),
          description: String.t(),
          inputs: [input_spec()],
          outputs: [output_spec()]
        }

  @type config :: map()
  @type context :: map()
  @type output :: map()

  @doc "Unique string key used in playlist_automations.steps[].action_type"
  @callback id() :: String.t()

  @doc "Validates action-specific config; returns errors for UI form display"
  @callback validate(config()) :: :ok | {:error, [String.t()]}

  @doc "Executes the action; receives static config, pipeline context, and user scope"
  @callback execute(config(), context(), Scope.t()) :: {:ok, output()} | {:error, term()}

  @doc "Returns the action's compile-time metadata: id, description, inputs, outputs"
  @callback meta() :: meta()

  # ---------------------------------------------------------------------------
  # DSL macros
  # ---------------------------------------------------------------------------

  defmacro __using__(_opts) do
    quote do
      @behaviour PremiereEcoute.Playlists.Automations.Action

      import PremiereEcoute.Playlists.Automations.Action,
        only: [action: 2, name: 1, description: 1, inputs: 1, outputs: 1, input: 2, input: 3, output: 2, output: 3]

      Module.register_attribute(__MODULE__, :action_id, accumulate: false)
      Module.register_attribute(__MODULE__, :action_description, accumulate: false)
      Module.register_attribute(__MODULE__, :action_inputs, accumulate: true)
      Module.register_attribute(__MODULE__, :action_outputs, accumulate: true)

      @before_compile PremiereEcoute.Playlists.Automations.Action
    end
  end

  @doc "Top-level action block. Sets the id and opens a scope for description, inputs, outputs."
  defmacro action(id, do: block) do
    quote do
      @action_id unquote(id)
      unquote(block)
    end
  end

  @doc "Sets the action's unique string identifier."
  defmacro name(id) do
    quote do
      @action_id unquote(id)
    end
  end

  @doc "Sets a human-readable description for the action."
  defmacro description(text) do
    quote do
      @action_description unquote(text)
    end
  end

  @doc "Groups input field declarations."
  defmacro inputs(do: block) do
    quote do
      unquote(block)
    end
  end

  @doc "Groups output field declarations."
  defmacro outputs(do: block) do
    quote do
      unquote(block)
    end
  end

  @doc "Declares an input field. Options: `required:` (boolean), `description:` (string)."
  defmacro input(key, type, opts \\ []) do
    quote do
      @action_inputs %{
        key: to_string(unquote(key)),
        type: unquote(type),
        required: Keyword.get(unquote(opts), :required, true),
        description: Keyword.get(unquote(opts), :description, "")
      }
    end
  end

  @doc "Declares an output field produced by the action."
  defmacro output(key, type, opts \\ []) do
    quote do
      @action_outputs %{
        key: to_string(unquote(key)),
        type: unquote(type),
        description: Keyword.get(unquote(opts), :description, "")
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Compile-time callback generation
  # ---------------------------------------------------------------------------

  defmacro __before_compile__(_env) do
    quote do
      @impl true
      def id, do: @action_id

      @impl true
      def meta do
        %{
          id: @action_id,
          description: @action_description || "",
          inputs: Enum.reverse(@action_inputs),
          outputs: Enum.reverse(@action_outputs)
        }
      end

      # AIDEV-NOTE: generated validate/1 checks presence of all required inputs;
      # actions with custom constraints should override this with @impl true def validate/1
      @impl true
      def validate(config) do
        required_keys =
          @action_inputs
          |> Enum.filter(& &1.required)
          |> Enum.map(& &1.key)

        errors =
          Enum.flat_map(required_keys, fn key ->
            case Map.get(config, key) do
              nil -> ["#{key} is required"]
              "" -> ["#{key} is required"]
              [] -> ["#{key} is required"]
              _ -> []
            end
          end)

        case errors do
          [] -> :ok
          _ -> {:error, errors}
        end
      end

      defoverridable validate: 1
    end
  end
end
