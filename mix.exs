defmodule ForkCleaner.MixProject do
  use Mix.Project

  def project do
    [
      app: :fork_cleaner,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: ForkCleaner]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tentacat, "~> 2.0"}
    ]
  end
end
