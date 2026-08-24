defmodule PremiereEcouteCore.Tracing do
  @moduledoc """
  OpenTelemetry helpers for carrying trace context across process boundaries.

  OpenTelemetry keeps the current trace context in the process dictionary, so it does not travel with
  a message sent to another process. Every time work crosses a process — a `GenStage` cast, a
  `Task`, a `GenServer` call — the context has to be captured on one side and attached on the other,
  otherwise the spans created downstream become orphaned roots instead of children.

  This module provides the two halves of that hand-off, plus a thin wrapper over
  `OpenTelemetry.Tracer.with_span/3` so that instrumented call sites stay readable.

      # in the sending process
      ctx = Tracing.context()

      # in the receiving process
      Tracing.with_context(ctx, fn ->
        Tracing.span "work.do" do
          :ok
        end
      end)

  See `docs/architecture/tracing.md` for the flow this was built for.
  """

  @doc """
  Captures the current OpenTelemetry context so it can be handed to another process.

  Returns an empty context when no span is active, which `with_context/2` treats as "no parent".
  """
  @spec context() :: OpenTelemetry.Ctx.t()
  def context, do: OpenTelemetry.Ctx.get_current()

  @doc """
  Runs `fun` with `ctx` attached as the current OpenTelemetry context, detaching it afterwards.

  Detaching is not optional. Broadway processors, GenStage consumers and pooled workers are
  long-lived and handle message after message in the same process; a context attached and never
  detached leaks into the next unit of work and produces traces that look plausible and are wrong.
  The context is therefore detached in an `after` block, so it is released even if `fun` raises.

  A `nil`, `:undefined` or empty context runs `fun` without touching the current context.
  """
  @spec with_context(OpenTelemetry.Ctx.t() | nil, (-> result)) :: result when result: var
  def with_context(ctx, fun) when ctx in [nil, :undefined], do: fun.()
  def with_context(ctx, fun) when is_map(ctx) and map_size(ctx) == 0, do: fun.()

  def with_context(ctx, fun) do
    token = OpenTelemetry.Ctx.attach(ctx)

    try do
      fun.()
    after
      OpenTelemetry.Ctx.detach(token)
    end
  end

  @doc """
  Builds span links from a list of captured contexts.

  Used to model a fan-in, where one span covers work batched from several unrelated traces and no
  single parent would be honest. Contexts that carry no span are dropped.
  """
  @spec links([OpenTelemetry.Ctx.t()]) :: [OpenTelemetry.link()]
  def links(contexts) do
    contexts
    |> Enum.reject(&(&1 in [nil, :undefined]))
    |> Enum.map(&OpenTelemetry.Tracer.current_span_ctx/1)
    |> Enum.reject(&(&1 == :undefined))
    |> OpenTelemetry.links()
  end

  @doc """
  Adds attributes to the span currently active in this process.

  Useful when an attribute value is only known once the work inside the span has run.
  """
  @spec set_attributes(map()) :: boolean()
  def set_attributes(attributes), do: OpenTelemetry.Tracer.set_attributes(attributes)

  @doc """
  Runs the block inside a new span named `name`.
  """
  @spec span(String.t(), keyword()) :: Macro.t()
  defmacro span(name, do: block) do
    quote do
      require OpenTelemetry.Tracer

      OpenTelemetry.Tracer.with_span unquote(name), %{} do
        unquote(block)
      end
    end
  end

  @doc """
  Runs the block inside a new span named `name`, with span start options.

  `opts` accepts the keys understood by `OpenTelemetry.Tracer.with_span/3`, notably `:attributes`,
  `:links` and `:kind`.
  """
  defmacro span(name, opts, do: block) do
    quote do
      require OpenTelemetry.Tracer

      OpenTelemetry.Tracer.with_span unquote(name), Map.new(unquote(opts)) do
        unquote(block)
      end
    end
  end
end
