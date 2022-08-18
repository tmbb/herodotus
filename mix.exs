defmodule Herodotus.MixProject do
  use Mix.Project

  def project do
    [
      app: :herodotus,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env)
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
       {:ecto, ">= 3.0.0"},
       {:ecto_sqlite3, ">= 0.0.0", only: :test}
    ]
  end
end
