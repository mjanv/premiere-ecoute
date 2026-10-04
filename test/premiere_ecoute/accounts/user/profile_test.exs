defmodule PremiereEcoute.Accounts.User.ProfileTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Profile

  describe "create/1" do
    test "can create an user with a default user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", username: "username"})

      assert %Profile{id: _, color_scheme: :system, language: :en} = user.profile
    end

    test "can create an user with an user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", username: "username", profile: %{color_scheme: :light, language: :it}})

      assert %Profile{id: _, color_scheme: :light, language: :it} = user.profile
    end
  end

  describe "update/1" do
    test "can update an user with an user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", username: "username", profile: %{color_scheme: :light, language: :it}})

      {:ok, user} =
        User.update(user, %{email: "user2@email.com", username: "username", profile: %{color_scheme: :dark, language: :en}})

      assert %Profile{id: _, color_scheme: :dark, language: :en} = user.profile
    end
  end

  describe "edit_user_profile/1" do
    test "can update an user with an user profile" do
      {:ok, user} = User.create(%{email: "user@email.com", username: "username", profile: %{color_scheme: :light, language: :it}})

      {:ok, user} = User.edit_user_profile(user, %{color_scheme: :dark, language: :en})

      assert %Profile{id: _, color_scheme: :dark, language: :en} = user.profile
    end
  end

  describe "get/1" do
    test "can get" do
      {:ok, user} =
        User.create(%{
          email: "user@email.com",
          username: "username",
          profile: %{color_scheme: :light, language: :it, radio_settings: %{visibility: :private}}
        })

      assert Profile.get(user, [:language]) == :it
      assert Profile.get(user, [:radio_settings, :visibility]) == :private
      assert Profile.get(user, [:radio_settings, :unknown]) == nil
      assert Profile.get(user, [:radio_settings, :unknown], :default) == :default
    end

    test "can get default values" do
      assert Profile.get(nil, [:unknown], :default) == :default
    end
  end

  describe "video_settings channels and replays" do
    @channel_id "UC" <> String.duplicate("a", 22)

    defp video_changeset(attrs, profile \\ %Profile{}) do
      Profile.changeset(profile, %{video_settings: attrs})
    end

    defp video_errors(changeset) do
      case changeset.changes do
        %{video_settings: vs} -> vs.errors
        _ -> []
      end
    end

    defp error_for(changeset, field) do
      changeset |> video_errors() |> Keyword.get(field) |> then(&(&1 && elem(&1, 0)))
    end

    defp child_errors(changeset, field) do
      changeset.changes.video_settings.changes
      |> Map.get(field, [])
      |> Enum.flat_map(& &1.errors)
    end

    defp saved_profile(attrs, user) do
      {:ok, user} = User.edit_user_profile(user, %{video_settings: attrs})
      user.profile
    end

    test "defaults to disabled, no channels, no replays and no tracking" do
      vs = %Profile{} |> Profile.changeset() |> Ecto.Changeset.apply_changes() |> Map.fetch!(:video_settings)

      assert %{reminders_enabled: false, channels: [], replays: [], tracking_since: nil} = vs
    end

    test "validates the channel id format" do
      cs = video_changeset(%{channels: [%{label: "Main", youtube_channel_id: "nope"}]})

      refute cs.valid?
      assert [{:youtube_channel_id, {_, _}}] = child_errors(cs, :channels)
    end

    test "requires a channel label of at most 40 characters" do
      cs = video_changeset(%{channels: [%{label: "", youtube_channel_id: @channel_id}]})
      refute cs.valid?

      cs = video_changeset(%{channels: [%{label: String.duplicate("a", 41), youtube_channel_id: @channel_id}]})
      refute cs.valid?
    end

    test "rejects duplicated channel labels and youtube channel ids" do
      other = "UC" <> String.duplicate("b", 22)

      cs =
        video_changeset(%{
          channels: [
            %{label: "Main", youtube_channel_id: @channel_id},
            %{label: "main", youtube_channel_id: other}
          ]
        })

      assert error_for(cs, :channels) =~ "label"

      cs =
        video_changeset(%{
          channels: [
            %{label: "Main", youtube_channel_id: @channel_id},
            %{label: "Archive", youtube_channel_id: @channel_id}
          ]
        })

      assert error_for(cs, :channels) =~ "channel id"
    end

    defp profile_with_channel do
      {:ok, user} = User.create(%{email: "user@email.com", username: "username"})
      profile = saved_profile(%{channels: [%{label: "Main", youtube_channel_id: @channel_id}]}, user)
      {user, profile, hd(profile.video_settings.channels)}
    end

    defp with_replays(profile, replays) do
      Profile.changeset(profile, %{video_settings: %{replays: replays}})
    end

    test "validates replay name and delay bounds" do
      {_, profile, %{id: cid}} = profile_with_channel()

      refute with_replays(profile, [%{name: "", delay_hours: 24, channel_id: cid}]).valid?
      refute with_replays(profile, [%{name: "raw", delay_hours: 0, channel_id: cid}]).valid?
      refute with_replays(profile, [%{name: "raw", delay_hours: 721, channel_id: cid}]).valid?
      assert with_replays(profile, [%{name: "raw", delay_hours: 720, channel_id: cid}]).valid?
    end

    test "replay delay defaults to 24 hours" do
      {_, profile, %{id: cid}} = profile_with_channel()
      cs = with_replays(profile, [%{name: "raw", channel_id: cid}])

      assert [%{delay_hours: 24}] = Ecto.Changeset.apply_changes(cs).video_settings.replays
    end

    test "requires a channel on every replay" do
      {_, profile, _} = profile_with_channel()

      cs = with_replays(profile, [%{name: "raw"}])

      refute cs.valid?
      assert [{:channel_id, {_, _}}] = child_errors(cs, :replays)
    end

    test "rejects replay names duplicated case-insensitively" do
      {_, profile, %{id: cid}} = profile_with_channel()
      cs = with_replays(profile, [%{name: "Raw", channel_id: cid}, %{name: "raw", channel_id: cid}])

      assert error_for(cs, :replays) =~ "unique"
    end

    test "rejects a replay targeting an unknown channel" do
      cs = video_changeset(%{replays: [%{name: "raw", channel_id: Ecto.UUID.generate()}]})

      assert error_for(cs, :replays) =~ "channel"
    end

    test "accepts a replay targeting a saved channel" do
      {_, profile, %{id: cid}} = profile_with_channel()

      assert with_replays(profile, [%{name: "raw", channel_id: cid}]).valid?
    end

    test "rejects deleting a channel still used by a replay" do
      {user, _, channel} = profile_with_channel()
      profile = saved_profile(%{replays: [%{name: "raw", channel_id: channel.id}]}, User.get!(user.id))

      cs = Profile.changeset(profile, %{video_settings: %{channels_drop: ["0"], channels: %{"0" => %{id: channel.id}}}})

      refute cs.valid?
    end

    test "adding replays does not enable the feature" do
      {user, _, %{id: cid}} = profile_with_channel()
      profile = saved_profile(%{replays: [%{name: "raw", channel_id: cid}]}, User.get!(user.id))

      assert %{reminders_enabled: false, tracking_since: nil} = profile.video_settings
    end

    test "sets tracking_since when the feature is enabled, and clears it when disabled" do
      {user, _, _} = profile_with_channel()
      profile = saved_profile(%{reminders_enabled: true}, User.get!(user.id))
      assert profile.video_settings.reminders_enabled
      assert profile.video_settings.tracking_since == Date.utc_today()

      cs = Profile.changeset(profile, %{video_settings: %{reminders_enabled: false}})

      assert Ecto.Changeset.apply_changes(cs).video_settings.tracking_since == nil
    end

    test "keeps tracking_since while the feature stays enabled" do
      {user, _, %{id: cid}} = profile_with_channel()
      profile = saved_profile(%{reminders_enabled: true}, User.get!(user.id))
      since = Date.add(Date.utc_today(), -3)
      profile = put_in(profile.video_settings.tracking_since, since)

      cs = with_replays(profile, [%{name: "raw", channel_id: cid}])

      assert Ecto.Changeset.apply_changes(cs).video_settings.tracking_since == since
    end
  end
end
