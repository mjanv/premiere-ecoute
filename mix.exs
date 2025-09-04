defmodule PremiereEcoute.MixProject do
  use Mix.Project

  def project do
    [
      app: :premiere_ecoute,
      name: "Premiere Ecoute",
      version: "1.0.0",
      elixir: "~> 1.18",
      source_url: "https://github.com/mjanv/premiere-ecoute",
      homepage_url: "https://premiere-ecoute.fr/",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [ignore_module_conflict: true],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:boundary] ++ Mix.compilers(), 
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_add_apps: [:mix],
        list_unused_filters: true
      ],
      listeners: [Phoenix.CodeReloader],
      docs: [
        main: "readme",
        extras: ["README.md"] ++ Path.wildcard("docs/**/*.md"),
        groups_for_extras: [
          Doc: Path.wildcard("docs/*.md")
        ],
        groups_for_modules: [
          "Backend - Accounts": ~r/^PremiereEcoute\.Accounts(\.|$)/,
          "Backend - Sessions": ~r/^PremiereEcoute\.Sessions(\.|$)/,
          "Backend - Core": ~r/^PremiereEcoute\.Core(\.|$)/,
          "Backend - APIs": ~r/^PremiereEcoute\.Apis(\.|$)/,
          Backend: ~r/^PremiereEcoute(\.|$)/,
          "Web - Accounts": ~r/^PremiereEcouteWeb\.Accounts(\.|$)/,
          "Web - Sessions": ~r/^PremiereEcouteWeb\.Sessions(\.|$)/,
          "Web - Static": ~r/^PremiereEcouteWeb\.Static(\.|$)/,
          "Web - Webhooks": ~r/^PremiereEcouteWeb\.Webhooks(\.|$)/,
          "Web - Plugs": ~r/^PremiereEcouteWeb\.Plugs(\.|$)/,
          "Web - Errors": ~r/^PremiereEcouteWeb\.Errors(\.|$)/,
          Web: ~r/^PremiereEcouteWeb(\.|$)/
        ]
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

  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      # Web
      {:bandit, "~> 1.5"},
      {:phoenix, "~> 1.8", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:phoenix_storybook, "~> 0.9.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons, github: "tailwindlabs/heroicons", tag: "v2.1.1", sparse: "optimized", app: false, compile: false, depth: 1},
      {:gettext, "~> 0.26"},
      {:dns_cluster, "~> 0.2"},
      {:plug_content_security_policy, "~> 0.2.1"},
      {:fun_with_flags, "~> 1.13"},
      {:fun_with_flags_ui, "~> 1.1"},
      # Backend
      {:dotenvy, "~> 1.0"},
      {:boundary, "~> 0.10"},
      {:uuid, "~> 1.1"},
      {:timex, "~> 3.7"},
      {:ex_cldr, "~> 2.0"},
      {:ex_cldr_dates_times, "~> 2.0"},
      {:req, "~> 0.5"},
      {:hackney, "~> 1.20"},
      {:jason, "~> 1.2"},
      {:cachex, "~> 4.1"},
      {:bcrypt_elixir, "~> 3.0"},
      {:postgrex, "~> 0.21"},
      {:ecto_sql, "~> 3.10"},
      {:cloak_ecto, "~> 1.3"},
      {:eventstore, "~> 1.4"},
      {:scrivener_ecto, "~> 3.0"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_twitch, "~> 0.1"},
      {:ueberauth_spotify, "~> 0.2"},
      {:nimble_publisher, "~> 1.1"},
      {:makeup_elixir, ">= 0.0.0"},
      {:makeup_erlang, ">= 0.0.0"},
      {:oban, "~> 2.19"},
      {:oban_web, "~> 2.11"},
      {:swoosh, "~> 1.19"},
      {:resend, "~> 0.4"},
      {:broadway, "~> 1.2"},
      {:xml_builder, "~> 2.1"},
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
      {:lazy_html, "~> 0.1", only: :test},
      {:bypass, "~> 2.1", only: :test},
      # Development
      {:doctor, "~> 0.22.0", only: :dev},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:tidewave, "~> 0.1", only: :dev},
      {:igniter, "~> 0.5", only: :dev}
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
        "tailwind storybook --minify",
        "phx.digest"
      ],
      gettext: ["gettext.extract", "gettext.merge priv/gettext"],
      # Quality
      clean: [
        "format",
        "credo --strict",
        "compile --warnings-as-errors"
      ],
      quality: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "dialyzer --format short",
        "gettext.check"
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
      dos: ["doctor", "docs --output priv/docs"],
      ready: ["format", "quality", "cmd mix test --color", "docs"],
      deploy: ["cmd fly deploy"],
      # CI/CD
      "ci.docs": ["docs --output doc"]
    ]
  end
end
