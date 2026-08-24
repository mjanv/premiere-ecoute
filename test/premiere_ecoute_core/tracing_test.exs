defmodule PremiereEcouteCore.TracingTest do
  use ExUnit.Case, async: false
  use PremiereEcoute.TracingCase

  alias PremiereEcouteCore.Tracing

  require Tracing

  setup do
    collect_spans()

    :ok
  end

  describe "with_context/2" do
    test "runs the work when there is nothing to attach" do
      assert Tracing.with_context(nil, fn -> :ran end) == :ran
      assert Tracing.with_context(:undefined, fn -> :ran end) == :ran
      assert Tracing.with_context(%{}, fn -> :ran end) == :ran
    end

    test "continues the captured trace in another process" do
      Tracing.span "outer" do
        ctx = Tracing.context()

        fn -> Tracing.with_context(ctx, fn -> Tracing.span("inner", do: :ok) end) end
        |> Task.async()
        |> Task.await()
      end

      spans = drain_spans()

      assert [inner] = spans_named(spans, "inner")
      assert [outer] = spans_named(spans, "outer")

      assert span_trace_id(inner) == span_trace_id(outer)
      assert span_parent_id(inner) == span_id(outer)
    end

    test "detaches afterwards, so the next unit of work starts its own trace" do
      ctx = Tracing.span("first", do: Tracing.context())

      Tracing.with_context(ctx, fn -> :ok end)
      Tracing.span("second", do: :ok)

      spans = drain_spans()

      assert [first] = spans_named(spans, "first")
      assert [second] = spans_named(spans, "second")

      assert span_parent_id(second) == :undefined
      refute span_trace_id(second) == span_trace_id(first)
    end

    test "detaches even when the work raises" do
      ctx = Tracing.span("first", do: Tracing.context())

      assert_raise RuntimeError, "boom", fn ->
        Tracing.with_context(ctx, fn -> raise "boom" end)
      end

      Tracing.span("after_raise", do: :ok)

      spans = drain_spans()

      assert [span] = spans_named(spans, "after_raise")
      assert span_parent_id(span) == :undefined
    end

    test "returns the value of the work" do
      ctx = Tracing.span("first", do: Tracing.context())

      assert Tracing.with_context(ctx, fn -> {:ok, 42} end) == {:ok, 42}
    end
  end

  describe "links/1" do
    test "builds one link per context, dropping the ones that carry no span" do
      a = Tracing.span("a", do: Tracing.context())
      b = Tracing.span("b", do: Tracing.context())

      links = Tracing.links([a, b, nil, :undefined, %{}])

      assert length(links) == 2

      spans = drain_spans()
      expected = spans |> Enum.filter(&(span_name(&1) in ["a", "b"])) |> Enum.map(&span_id/1) |> Enum.sort()

      assert links |> Enum.map(&link_span_id/1) |> Enum.sort() == expected
    end

    test "returns no links for an empty list" do
      assert Tracing.links([]) == []
    end
  end

  describe "span/2" do
    test "records the attributes it is given" do
      Tracing.span("work.do", attributes: %{"work.id" => 7}, do: :ok)

      assert [span] = spans_named(drain_spans(), "work.do")
      assert span_attributes(span)["work.id"] == 7
    end

    test "returns the value of the block" do
      assert Tracing.span("work.do", do: :result) == :result
    end
  end
end
