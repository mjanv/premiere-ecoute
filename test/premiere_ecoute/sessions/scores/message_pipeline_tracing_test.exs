defmodule PremiereEcoute.Sessions.Scores.MessagePipelineTracingTest do
  @moduledoc """
  Covers the first distributed trace: a Twitch chat vote followed from the publishing process into
  the Broadway processor and batcher. See `docs/architecture/tracing.md`.
  """

  use PremiereEcoute.DataCase, async: false
  use PremiereEcoute.TracingCase

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcouteCore.Cache
  alias PremiereEcouteCore.Tracing

  require Tracing

  @pipeline PremiereEcoute.Sessions.Scores.MessagePipeline

  setup do
    start_supervised(@pipeline)

    user = user_fixture(%{twitch: %{user_id: "1234"}})
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id, status: :active})
    {:ok, session} = ListeningSession.next_track(session)

    Cache.put(:sessions, "1234", Map.take(session, [:id, :vote_options, :current_track_id]))

    collect_spans()

    {:ok, %{session: session}}
  end

  defp vote(value, viewer) do
    %MessageSent{broadcaster_id: "1234", user_id: viewer, message: value, is_streamer: false}
  end

  defp publish_in_trace(value, viewer) do
    Tracing.span "twitch.chat_message", attributes: %{"twitch.user_id" => viewer} do
      PremiereEcouteCore.publish(@pipeline, vote(value, viewer))
    end
  end

  describe "trace continuity" do
    test "carries the publisher's trace into the Broadway processor", %{session: session} do
      publish_in_trace("5", "viewer1")

      spans = drain_spans(1_000)

      assert [webhook] = spans_named(spans, "twitch.chat_message")
      assert [process] = spans_named(spans, "vote.process")

      assert span_trace_id(process) == span_trace_id(webhook)
      assert span_parent_id(process) == span_id(webhook)

      attributes = span_attributes(process)
      assert attributes["session.id"] == session.id
      assert attributes["track.id"] == session.current_track.id
      assert attributes["vote.value"] == "5"
      assert attributes["vote.outcome"] == "accepted"
    end

    test "starts its own trace when the publisher is not instrumented" do
      PremiereEcouteCore.publish(@pipeline, vote("5", "viewer1"))

      spans = drain_spans(1_000)

      assert [process] = spans_named(spans, "vote.process")
      assert span_parent_id(process) == :undefined
    end

    test "does not leak context from one message into the next" do
      for i <- 1..5, do: publish_in_trace("#{i}", "viewer#{i}")

      spans = drain_spans(1_500)
      processes = spans_named(spans, "vote.process")

      assert length(processes) == 5
      assert processes |> Enum.map(&span_trace_id/1) |> Enum.uniq() |> length() == 5
    end

    test "marks a message that carries no vote as rejected" do
      publish_in_trace("not a vote", "viewer1")

      spans = drain_spans(1_000)

      assert [process] = spans_named(spans, "vote.process")
      assert span_attributes(process)["vote.outcome"] == "rejected"
    end
  end

  describe "batch fan-in" do
    test "links the batch span back to every vote it wrote", %{session: session} do
      for i <- 1..5, do: publish_in_trace("#{i}", "viewer#{i}")

      spans = drain_spans(1_500)

      processes = spans_named(spans, "vote.process")
      assert [batch] = spans_named(spans, "vote.batch_write")

      assert span_attributes(batch)["batch.size"] == 5
      assert span_attributes(batch)["session.id"] == session.id

      links = span_links(batch)
      assert length(links) == 5

      assert links |> Enum.map(&link_span_id/1) |> Enum.sort() ==
               processes |> Enum.map(&span_id/1) |> Enum.sort()
    end

    test "makes the batch a trace of its own rather than adopting one vote's trace" do
      for i <- 1..5, do: publish_in_trace("#{i}", "viewer#{i}")

      spans = drain_spans(1_500)

      processes = spans_named(spans, "vote.process")
      assert [batch] = spans_named(spans, "vote.batch_write")

      assert span_parent_id(batch) == :undefined
      assert Enum.all?(processes, fn process -> span_trace_id(process) != span_trace_id(batch) end)
    end

    test "breaks the batch down into its write, report and broadcast" do
      for i <- 1..5, do: publish_in_trace("#{i}", "viewer#{i}")

      spans = drain_spans(1_500)

      assert [batch] = spans_named(spans, "vote.batch_write")
      assert [insert] = spans_named(spans, "vote.insert_all")
      assert [report] = spans_named(spans, "report.generate")
      assert [broadcast] = spans_named(spans, "session_summary.broadcast")

      for child <- [insert, report, broadcast] do
        assert span_parent_id(child) == span_id(batch)
        assert span_trace_id(child) == span_trace_id(batch)
      end

      assert span_attributes(insert)["db.rows"] == 5
      assert span_attributes(report)["report.track_count"] == 1
    end
  end

  describe "behaviour under instrumentation" do
    test "still records the votes", %{session: session} do
      for i <- 1..5, do: publish_in_trace("#{i}", "viewer#{i}")

      drain_spans(1_500)

      votes = Vote.all(where: [session_id: session.id])

      assert length(votes) == 5
      assert votes |> Enum.map(fn vote -> vote.value end) |> Enum.sort() == ~w(1 2 3 4 5)
    end
  end
end
