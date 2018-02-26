defmodule FirmataExample.Mixfile do
  use Mix.Project

  def project do
    [
      app: :firmata_example,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :firmata, :nerves_uart],
      mod: {FirmataExample.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:firmata, github: "entone/firmata", branch: "master"},
      {:nerves_uart, "~> 1.0", override: true},
    ]
  end
end
