defmodule PremiereEcoute.TracingCase do
  @moduledoc """
  Test helpers for asserting on emitted OpenTelemetry spans.

  Swaps the configured span processor for a simple, synchronous one that exports every finished span
  as a `{:span, span}` message to the test process, so a test can `assert_receive` on it.

      defmodule MyTest do
        use ExUnit.Case, async: false
        use PremiereEcoute.TracingCase

        test "emits a span" do
          collect_spans()

          Tracing.span("work.do", do: :ok)

          assert_receive {:span, span}
          assert span_name(span) == "work.do"
        end
      end

  Because it restarts the `:opentelemetry` application, tests using it must run with `async: false`.
  """

  require Record

  Record.defrecordp(:otel_span, :span, Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl"))
  Record.defrecordp(:otel_link, :link, Record.extract(:link, from_lib: "opentelemetry/include/otel_span.hrl"))

  @doc false
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      import PremiereEcoute.TracingCase
    end
  end

  @doc """
  Routes every finished span to the calling process as a `{:span, span}` message.

  Restores the original configuration when the test exits.
  """
  @spec collect_spans() :: :ok
  def collect_spans do
    span_processor = :application.get_env(:opentelemetry, :span_processor)
    traces_exporter = :application.get_env(:opentelemetry, :traces_exporter)

    ExUnit.Callbacks.on_exit(fn ->
      :application.stop(:opentelemetry)
      :application.unset_env(:opentelemetry, :processors)
      restore(:span_processor, span_processor)
      restore(:traces_exporter, traces_exporter)
      :application.start(:opentelemetry)
    end)

    :application.stop(:opentelemetry)
    # `span_processor` takes precedence over `processors`, so it has to go before ours is read
    :application.unset_env(:opentelemetry, :span_processor)
    :application.unset_env(:opentelemetry, :traces_exporter)
    :application.set_env(:opentelemetry, :processors, [{:otel_simple_processor, %{}}])
    :application.start(:opentelemetry)

    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    :ok
  end

  @doc "Name of a collected span."
  @spec span_name(tuple()) :: String.t() | atom()
  def span_name(span), do: otel_span(span, :name)

  @doc "Attributes of a collected span, as a plain map."
  @spec span_attributes(tuple()) :: map()
  def span_attributes(span), do: :otel_attributes.map(otel_span(span, :attributes))

  @doc "Links of a collected span, as a list."
  @spec span_links(tuple()) :: list()
  def span_links(span), do: :otel_links.list(otel_span(span, :links))

  @doc "Trace id of a collected span."
  @spec span_trace_id(tuple()) :: integer() | :undefined
  def span_trace_id(span), do: otel_span(span, :trace_id)

  @doc "Span id of a collected span."
  @spec span_id(tuple()) :: integer() | :undefined
  def span_id(span), do: otel_span(span, :span_id)

  @doc "Parent span id of a collected span, or `:undefined` when it is a root span."
  @spec span_parent_id(tuple()) :: integer() | :undefined
  def span_parent_id(span), do: otel_span(span, :parent_span_id)

  @doc """
  Collects every span emitted until `timeout` milliseconds pass without a new one.

  Returns them in the order they finished. Prefer this over a bare `assert_receive` when the work
  under test is asynchronous, so that assertions do not depend on the order spans happen to end in.
  """
  @spec drain_spans(non_neg_integer()) :: [tuple()]
  def drain_spans(timeout \\ 500) do
    receive do
      {:span, span} -> [span | drain_spans(timeout)]
    after
      timeout -> []
    end
  end

  @doc "Filters collected spans by name."
  @spec spans_named([tuple()], String.t()) :: [tuple()]
  def spans_named(spans, name), do: Enum.filter(spans, fn span -> span_name(span) == name end)

  @doc "Span id a link points at."
  @spec link_span_id(tuple()) :: integer()
  def link_span_id(link), do: otel_link(link, :span_id)

  @doc "Trace id a link points at."
  @spec link_trace_id(tuple()) :: integer()
  def link_trace_id(link), do: otel_link(link, :trace_id)

  defp restore(_key, :undefined), do: :ok
  defp restore(key, {:ok, value}), do: :application.set_env(:opentelemetry, key, value)
end
