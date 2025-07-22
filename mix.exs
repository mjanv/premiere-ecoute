defmodule PremiereEcoute.MixProject do
  use Mix.Project

  def project do
    [
      app: :premiere_ecoute,
      name: "Premiere Ecoute",
      version: "0.1.0",
      elixir: "~> 1.18",
      source_url: "https://github.com/mjanv/premiere_ecoute",
      homepage_url: "https://premiere-ecoute.fly.dev/",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [ignore_module_conflict: true],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_add_apps: [:mix],
        list_unused_filters: true
      ],
      listeners: [Phoenix.CodeReloader],
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
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
      preferred_envs: [test: :test, "test.cover": :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Web
      {:bandit, "~> 1.5"},
      {:phoenix, "~> 1.8.0-rc.4", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.9"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons, github: "tailwindlabs/heroicons", tag: "v2.1.1", sparse: "optimized", app: false, compile: false, depth: 1},
      {:gettext, "~> 0.26"},
      {:dns_cluster, "~> 0.2"},
      # Backend
      {:dotenvy, "~> 1.0"},
      {:uuid, "~> 1.1"},
      {:req, "~> 0.5"},
      {:hackney, "~> 1.20"},
      {:jason, "~> 1.2"},
      {:cachex, "~> 4.1"},
      {:bcrypt_elixir, "~> 3.0"},
      {:postgrex, "~> 0.20.0"},
      {:ecto_sql, "~> 3.10"},
      {:eventstore, "~> 1.4"},
      {:scrivener_ecto, "~> 3.0"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_twitch, "~> 0.1"},
      {:ueberauth_spotify, "~> 0.2"},
      {:nimble_publisher, "~> 1.1"},
      {:makeup_elixir, ">= 0.0.0"},
      {:makeup_erlang, ">= 0.0.0"},
      # Observability
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:prom_ex, "~> 1.11.0"},
      {:sentry, "~> 11.0.1"},
      # Code quality
      {:credo, "~> 1.7", only: [:dev]},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      # Audit
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      # Tests
      {:hammox, "~> 0.7", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      # Development
      {:doctor, "~> 0.22.0", only: :dev},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:tidewave, "~> 0.1", only: :dev}
    ]
  end

  defp aliases do
    [
      # Setup
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["event_store.create", "ecto.create", "event_store.init", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["event_store.drop", "ecto.drop", "ecto.setup"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind premiere_ecoute", "esbuild premiere_ecoute"],
      "assets.deploy": [
        "tailwind premiere_ecoute --minify",
        "esbuild premiere_ecoute --minify",
        "phx.digest"
      ],
      gettext: ["gettext.extract", "gettext.merge priv/gettext"],
      # Quality
      quality: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "dialyzer --format short"
        # "gettext.check"
      ],
      # Audit
      audit: [
        "sobelow --compact",
        "deps.audit",
        "hex.outdated --within-requirements"
      ],
      # Tests
      test: [
        "event_store.drop --quiet",
        "event_store.create --quiet",
        "ecto.create --quiet",
        "event_store.init --quiet",
        "ecto.migrate --quiet",
        "test"
      ],
      "test.cover": [
        "event_store.drop --quiet",
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "coveralls.html",
        "cmd firefox cover/excoveralls.html"
      ],
      # Deployment
      docs: ["doctor", "docs"],
      ready: ["format", "quality", "cmd mix test --color"],
      deploy: ["cmd fly deploy"],
      db: ["cmd fly postgres connect -a premiere-ecoute-db"]
    ]
  end
end
