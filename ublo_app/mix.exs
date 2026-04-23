defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :ublo_app,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MyApp.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:postgrex, "~> 0.22.0"},
      {:ecto_sql, "~> 3.13"},
      {:oban, "~> 2.19"},
      {:jason, "~> 1.4"}
    ]
  end
end
