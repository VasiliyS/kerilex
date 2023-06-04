defmodule Kerilex.MixProject do
  use Mix.Project

  def project do
    [
      app: :kerilex,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

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
      {:argon2_elixir, "~>  3.0"},
      {:blake3, path: "../../elixir/blake3"},
      {:enacl, "~> 1.2"},
      {:jason, "~> 1.4.0"},
      {:ratio, "~> 3.0"},
      {:finch, "~> 0.15.0"},
      {:mint, "1.5.1"},
      {:benchee, "~> 1.1", only: :dev }
    ]
  end
end
