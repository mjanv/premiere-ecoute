defmodule PremiereEcouteCore.CommandBus.Handler do
  @moduledoc """
  Base module for command handlers.

  Provides command registration and default implementations for validation and handling. Handlers must declare which commands they handle using the `command/1` macro and implement `validate/1` and `handle/1` callbacks.

  ## Usage

      defmodule MyHandler do
        use PremiereEcouteCore.CommandBus.Handler

        command MyCommand

        def validate(%MyCommand{} = cmd) do
          # Validate the command
          {:ok, cmd}
        end

        def handle(%MyCommand{} = cmd) do
          # Execute the command and return events
          {:ok, [%MyEvent{}]}
        end
      end
  """

  @doc """
  Injects command handler functionality into using module.

  Registers command attributes, provides default validate/handle implementations, and sets up Gettext integration.
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      use Gettext, backend: PremiereEcoute.Gettext

      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :commands, accumulate: true)

      @doc "Command validation"
      @spec validate(struct()) :: {:ok, struct()} | {:error, any()}
      def validate(command), do: {:ok, command}

      @doc "Command handling"
      @spec handle(struct()) :: {:ok, [struct()]} | {:error, any()}
      def handle(_command), do: {:ok, []}

      defoverridable validate: 1, handle: 1
    end
  end

  @doc """
  Finalizes command handler compilation.

  Generates commands_or_events function returning registered command modules.
  """
  @spec __before_compile__(Macro.Env.t()) :: Macro.t()
  defmacro __before_compile__(_env) do
    quote do
      @doc "Returns registered commands."
      @spec commands_or_events() :: [module()]
      def commands_or_events, do: @commands
    end
  end

  @doc """
  Registers command module for handler.

  Declares which command this handler processes. Can be called multiple times for multiple commands.
  """
  @spec command(module()) :: Macro.t()
  defmacro command(command) do
    quote do
      @commands unquote(command)
    end
  end

  @callback validate(struct()) :: {:ok, struct()} | {:error, any()}
  @callback handle(struct()) :: {:ok, [struct()]} | {:error, any()}
end
