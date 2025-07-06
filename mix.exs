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

  def cli do
    [
      default_task: "phx.server",
      preferred_envs: [docs: :docs]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Web
      {:bandit, "~> 1.5"},
      {:phoenix, "~> 1.8.0-rc.3", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.9"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:gettext, "~> 0.26"},
      {:dns_cluster, "~> 0.2"},
      # Backend
      {:req, "~> 0.5"},
      {:websockex, "~> 0.4.3"},
      {:jason, "~> 1.2"},
      {:cachex, "~> 3.3"},
      {:bcrypt_elixir, "~> 3.0"},
      {:postgrex, "~> 0.20.0"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, "~> 0.12"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_twitch, "~> 0.1"},
      {:ueberauth_spotify, "~> 0.2"},
      # Observability
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:prom_ex, "~> 1.11.0"},
      # Code quality
      {:credo, "~> 1.7"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      # Audit
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      # Tests
      {:mox, "~> 1.2"},
      # Development
      {:tidewave, "~> 0.1", only: :dev}
    ]
  end

  defp aliases do
    [
      # Setup
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind premiere_ecoute", "esbuild premiere_ecoute"],
      "assets.deploy": [
        "tailwind premiere_ecoute --minify",
        "esbuild premiere_ecoute --minify",
        "phx.digest"
      ],
      # Quality
      quality: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "dialyzer --format short"
      ],
      # Audit
      audit: [
        "sobelow --compact",
        "deps.audit",
        "hex.outdated --within-requirements"
      ],
      # Tests
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      # Deployment
      deploy: ["format", "compile --warnings-as-errors", "cmd fly deploy"]
    ]
  end
end
