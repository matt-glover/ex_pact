defmodule ExPact.MixProject do
  use Mix.Project

  @repo_url "https://github.com/matt-glover/ex_pact"

  def project do
    [
      app: :ex_pact,
      version: "0.1.0-unstable.1",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: @repo_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExPact.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description() do
    """
    Enables consumer driven contract testing, providing a mock service and DSL for the consumer project,
    and interaction playback and verification for the service provider project.

    Integrates the https://pact.io specification with ex_unit testing.
    """
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
