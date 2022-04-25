defmodule ChangeStream.MixProject do
  use Mix.Project

  def project do
    [
      app: :change_stream,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ChangeStream, []}
    ]
  end

  defp deps do
    [
      {:elixir_uuid, "~> 1.2"},
      {:poison, "~> 3.1"},
      {:mongodb_driver, "~> 0.8.3"},
      {:destructure, "~> 0.2.3"},
    ]
  end
end
