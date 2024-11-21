defmodule Obanalyze.MixProject do
  use Mix.Project

  @version "1.3.1"
  @source_url "https://github.com/egze/obanalyze"

  def project do
    [
      app: :obanalyze,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Obanalyze",
      docs: docs(),
      description: "Real-time Monitoring for Oban with Phoenix.LiveDashboard",
      source_url: @source_url
    ]
  end

  def application do
    []
  end

  defp docs do
    [
      main: "Obanalyze",
      source_ref: "v#{@version}",
      source_url: @source_url,
      nest_modules_by_prefix: [Obanalyze]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:phoenix_live_dashboard, ">= 0.8.5"},
      {:floki, ">= 0.30.0", only: :test},
      {:ecto_sqlite3, ">= 0.0.0", only: :test},
      {:oban, "~> 2.15"}
    ]
  end

  defp package do
    [
      maintainers: ["Aleksandr Lossenko"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/egze/obanalyze"},
      files: ~w(lib CHANGELOG.md LICENSE.md mix.exs README.md)
    ]
  end
end
