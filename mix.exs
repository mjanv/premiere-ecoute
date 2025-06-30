defmodule PremiereEcoute.MixProject do
  use Mix.Project

  def project do
    [
      app: :premiere_ecoute,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix],
        list_unused_filters: true
      ],
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {PremiereEcoute.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.8.0-rc.3", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, "~> 0.12"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.9"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:oauth2, "~> 2.0"},
      {:tesla, "~> 1.4"},
      {:broadway, "~> 1.0"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_twitch, "~> 0.1"},
      {:credo, "~> 1.7"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:mox, "~> 1.2"},
      {:websockex, "~> 0.4.3"},
      {:tidewave, "~> 0.1", only: :dev}
    ]
  end

  defp aliases do
    [
      # Setup
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      # Quality
      quality: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "dialyzer --format short"
      ],
      # Tests
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      # Deployment
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind premiere_ecoute", "esbuild premiere_ecoute"],
      "assets.deploy": [
        "tailwind premiere_ecoute --minify",
        "esbuild premiere_ecoute --minify",
        "phx.digest"
      ]
    ]
  end
end
