defmodule AgentYard.MixProject do
  use Mix.Project

  def project do
    [
      app: :agentyard,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :inets, :ssl],
      mod: {AgentYard.Application, []}
    ]
  end

  defp deps do
    [
      {:bcrypt_elixir, "~> 3.2"},
      {:bandit, "~> 1.12"},
      {:ecto_sql, "~> 3.14"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:oban, "~> 2.24"},
      {:phoenix, "~> 1.8.14"},
      {:phoenix_ecto, "~> 4.7"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_live_reload, "~> 1.7", only: :dev},
      {:phoenix_live_view, "~> 1.2.12"},
      {:postgrex, "~> 0.22.4"},
      {:jason, "~> 1.4"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:gettext, "~> 0.26"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "assets.setup": ["cmd --cd assets npm install"],
      "assets.deploy": ["esbuild agentyard"]
    ]
  end
end
