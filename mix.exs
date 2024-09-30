defmodule Kerilex.MixProject do
  use Mix.Project

  def project do
    [
      app: :kerilex,
      version: "0.3.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: compiler_paths(Mix.env())
    ]
  end

  def compiler_paths(env) when env in [:test, :dev], do: ["test/helpers"] ++ compiler_paths(:prod)
  def compiler_paths(:prod), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      #{:argon2_elixir, "~>  4.0"},
      {:blake3, "~> 1.0"},
      # {:enacl, "~> 1.2"},
      {:enacl, git: "https://github.com/aeternity/enacl.git"},
      {:jason, "~> 1.4"},
      {:ratio, "~> 4.0"},
      {:finch, "~> 0.19.0"},
      {:req, "~> 0.5"},
      {:event_bus, "~> 1.7"},
      {:gen_stage, "~> 1.2"},
      {:poolex, "~> 1.0"},
      # {:nanoid, "~> 2.1"},
      #{:mint, "~> 1.6"},
      {:benchee, "~> 1.3", only: :dev}
    ]
  end
end
