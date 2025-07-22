defmodule ExGitManager.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_git_manager,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ExGitManager.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # For making HTTP requests to GitHub API
      {:finch, "~> 0.17"},
      # For encoding/decoding JSON
      {:jason, "~> 1.0"}
    ]
  end
end
