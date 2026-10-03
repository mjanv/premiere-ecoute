defmodule PremiereEcoute.Accounts.User.Profile do
  @moduledoc """
  User profile settings.

  Embedded schema for user preferences including color scheme (light/dark/system), language (en/fr/it/pt),
  and widget color settings (hex strings) used in OBS overlay displays.
  """

  use PremiereEcouteCore.Aggregate.Object

  # alias PremiereEcoute.Accounts.User

  @schemes [:light, :dark, :system]
  @languages [:en, :fr, :it, :pt]
  @hex_color_regex ~r/^#[0-9A-Fa-f]{6}$/
  @youtube_channel_id_regex ~r/^UC[\w-]{22}$/

  @type t :: %__MODULE__{
          color_scheme: :light | :dark | :system,
          language: :en | :fr | :it | :pt,
          timezone: String.t(),
          session_reminder: String.t() | nil,
          sound_effects_enabled: boolean(),
          widget_settings: map() | nil,
          radio_settings: map() | nil,
          chat_settings: map() | nil,
          video_settings: map() | nil
        }

  embedded_schema do
    field :color_scheme, Ecto.Enum, values: @schemes, default: :system
    field :language, Ecto.Enum, values: @languages, default: :en
    field :timezone, :string, default: "UTC"
    field :session_reminder, :string
    field :sound_effects_enabled, :boolean, default: true

    embeds_one :widget_settings, WidgetSettings, on_replace: :update, primary_key: false do
      field :color_primary, :string, default: "#5b21b6"
      field :color_secondary, :string, default: "#be123c"
    end

    embeds_one :radio_settings, RadioSettings, on_replace: :update, primary_key: false do
      field :enabled, :boolean, default: false
      field :retention_days, :integer, default: 7
      field :visibility, Ecto.Enum, values: [:private, :public], default: :public
    end

    embeds_one :chat_settings, ChatSettings, on_replace: :update, primary_key: false do
      field :save_wantlist, :boolean, default: false
      field :vote_enabled, :boolean, default: true
    end

    embeds_one :video_settings, VideoSettings, on_replace: :update, primary_key: false do
      field :show_name, :string, default: "PREMIÈRE ÉCOUTE"
      field :title_template, :string, default: "{show_name} : \"{title}\" by {artist}"
      field :tracking_since, :date

      embeds_many :channels, Channel, on_replace: :delete, primary_key: {:id, :binary_id, autogenerate: true} do
        field :label, :string
        field :youtube_channel_id, :string
      end

      embeds_many :replays, Replay, on_replace: :delete, primary_key: {:id, :binary_id, autogenerate: true} do
        field :name, :string
        field :channel_id, :binary_id
        field :delay_hours, :integer, default: 24
      end
    end
  end

  def get(user, path, default \\ nil)

  def get(%{profile: %__MODULE__{} = profile}, path, default) do
    Enum.reduce_while(path, profile, fn key, acc ->
      case acc do
        nil -> {:halt, default}
        _ -> {:cont, Map.get(acc, key, default)}
      end
    end)
  end

  def get(_user, _path, default), do: default

  @doc "User profile changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(profile, attrs \\ %{}) do
    profile
    |> Map.put(:radio_settings, Map.get(profile, :radio_settings) || %__MODULE__.RadioSettings{})
    |> Map.put(:widget_settings, Map.get(profile, :widget_settings) || %__MODULE__.WidgetSettings{})
    |> Map.put(:chat_settings, Map.get(profile, :chat_settings) || %__MODULE__.ChatSettings{})
    |> Map.put(:video_settings, Map.get(profile, :video_settings) || %__MODULE__.VideoSettings{})
    |> cast(attrs, [:color_scheme, :language, :timezone, :session_reminder, :sound_effects_enabled])
    |> validate_length(:session_reminder, max: 2000)
    |> cast_embed(:widget_settings, with: &widget_settings_changeset/2)
    |> cast_embed(:radio_settings, with: &radio_settings_changeset/2)
    |> cast_embed(:chat_settings, with: &chat_settings_changeset/2)
    |> cast_embed(:video_settings, with: &video_settings_changeset/2)
    |> validate_required([:color_scheme, :language])
    |> validate_inclusion(:color_scheme, @schemes)
    |> validate_inclusion(:language, @languages)
    |> validate_timezone()
  end

  defp widget_settings_changeset(settings, attrs) do
    settings
    |> cast(attrs, [:color_primary, :color_secondary])
    |> validate_format(:color_primary, @hex_color_regex, message: "must be a valid hex color (e.g. #a1b2c3)")
    |> validate_format(:color_secondary, @hex_color_regex, message: "must be a valid hex color (e.g. #a1b2c3)")
  end

  defp radio_settings_changeset(settings, attrs) do
    settings
    |> cast(attrs, [:enabled, :retention_days, :visibility])
    |> validate_number(:retention_days, greater_than: 0)
  end

  defp chat_settings_changeset(settings, attrs) do
    cast(settings, attrs, [:save_wantlist, :vote_enabled])
  end

  defp video_settings_changeset(settings, attrs) do
    settings
    |> cast(attrs, [:show_name, :title_template])
    |> validate_length(:show_name, max: 100)
    |> validate_length(:title_template, max: 200)
    |> cast_embed(:channels, with: &channel_changeset/2, sort_param: :channels_sort, drop_param: :channels_drop)
    |> cast_embed(:replays, with: &replay_changeset/2, sort_param: :replays_sort, drop_param: :replays_drop)
    |> validate_unique_channels()
    |> validate_unique_replays()
    |> validate_replay_channels()
    |> put_tracking_since(settings)
  end

  defp channel_changeset(channel, attrs) do
    channel
    |> cast(attrs, [:label, :youtube_channel_id])
    |> update_change(:label, &String.trim/1)
    |> update_change(:youtube_channel_id, &String.trim/1)
    |> validate_required([:label, :youtube_channel_id])
    |> validate_length(:label, min: 1, max: 40)
    |> validate_format(:youtube_channel_id, @youtube_channel_id_regex, message: "must be a YouTube channel id (UC...)")
  end

  defp replay_changeset(replay, attrs) do
    replay
    |> cast(attrs, [:name, :channel_id, :delay_hours])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :channel_id, :delay_hours])
    |> validate_length(:name, min: 1, max: 40)
    |> validate_number(:delay_hours, greater_than_or_equal_to: 1, less_than_or_equal_to: 720)
  end

  defp validate_unique_channels(changeset) do
    channels = get_field(changeset, :channels) || []

    cond do
      duplicates?(channels, &String.downcase(&1.label || "")) -> add_error(changeset, :channels, "label must be unique")
      duplicates?(channels, & &1.youtube_channel_id) -> add_error(changeset, :channels, "channel id must be unique")
      true -> changeset
    end
  end

  defp validate_unique_replays(changeset) do
    replays = get_field(changeset, :replays) || []

    if duplicates?(replays, &String.downcase(&1.name || "")),
      do: add_error(changeset, :replays, "name must be unique"),
      else: changeset
  end

  defp validate_replay_channels(changeset) do
    channel_ids = changeset |> get_field(:channels) |> List.wrap() |> MapSet.new(& &1.id)

    changeset
    |> get_field(:replays)
    |> List.wrap()
    |> Enum.any?(&(&1.channel_id not in channel_ids))
    |> case do
      true -> add_error(changeset, :replays, "channel must exist (reassign replays before deleting a channel)")
      false -> changeset
    end
  end

  defp put_tracking_since(changeset, settings) do
    previous = settings.replays || []

    case {previous, get_field(changeset, :replays) || []} do
      {_, []} -> put_change(changeset, :tracking_since, nil)
      {[], _} -> put_change(changeset, :tracking_since, Date.utc_today())
      _ -> changeset
    end
  end

  defp duplicates?(items, fun) do
    values = items |> Enum.map(fun) |> Enum.reject(&(&1 in [nil, ""]))
    length(values) != length(Enum.uniq(values))
  end

  defp validate_timezone(changeset) do
    validate_change(changeset, :timezone, fn :timezone, tz ->
      if PremiereEcouteCore.Timezone.exists?(tz), do: [], else: [timezone: "is not a valid timezone"]
    end)
  end
end

defimpl Jason.Encoder, for: PremiereEcoute.Accounts.User.Profile do
  def encode(profile, opts) do
    profile
    |> Map.update!(:widget_settings, &(&1 || %PremiereEcoute.Accounts.User.Profile.WidgetSettings{}))
    |> Map.update!(:radio_settings, &(&1 || %PremiereEcoute.Accounts.User.Profile.RadioSettings{}))
    |> Map.update!(:chat_settings, &(&1 || %PremiereEcoute.Accounts.User.Profile.ChatSettings{}))
    |> Map.update!(:video_settings, &(&1 || %PremiereEcoute.Accounts.User.Profile.VideoSettings{}))
    |> Map.take([
      :color_scheme,
      :language,
      :timezone,
      :session_reminder,
      :sound_effects_enabled,
      :widget_settings,
      :radio_settings,
      :chat_settings,
      :video_settings
    ])
    |> Jason.Encode.map(opts)
  end
end

defimpl Jason.Encoder, for: PremiereEcoute.Accounts.User.Profile.WidgetSettings do
  def encode(settings, opts) do
    Jason.Encode.map(Map.take(settings, [:color_primary, :color_secondary]), opts)
  end
end

defimpl Jason.Encoder, for: PremiereEcoute.Accounts.User.Profile.RadioSettings do
  def encode(settings, opts) do
    Jason.Encode.map(Map.take(settings, [:enabled, :retention_days, :visibility]), opts)
  end
end

defimpl Jason.Encoder, for: PremiereEcoute.Accounts.User.Profile.ChatSettings do
  def encode(settings, opts) do
    Jason.Encode.map(Map.take(settings, [:save_wantlist, :vote_enabled]), opts)
  end
end

defimpl Jason.Encoder, for: PremiereEcoute.Accounts.User.Profile.VideoSettings do
  def encode(settings, opts) do
    Jason.Encode.map(Map.take(settings, [:show_name, :title_template, :tracking_since, :channels, :replays]), opts)
  end
end

defimpl Jason.Encoder, for: PremiereEcoute.Accounts.User.Profile.VideoSettings.Channel do
  def encode(channel, opts) do
    Jason.Encode.map(Map.take(channel, [:id, :label, :youtube_channel_id]), opts)
  end
end

defimpl Jason.Encoder, for: PremiereEcoute.Accounts.User.Profile.VideoSettings.Replay do
  def encode(replay, opts) do
    Jason.Encode.map(Map.take(replay, [:id, :name, :channel_id, :delay_hours]), opts)
  end
end
