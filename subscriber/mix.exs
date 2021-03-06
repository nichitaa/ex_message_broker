defmodule Subscriber.MixProject do
  use Mix.Project

  def project do
    [
      app: :subscriber,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Subscriber, []}
    ]
  end

  defp deps do
    [
      {:poison, "~> 3.1"},
      {:destructure, "~> 0.2.3"},
    ]
  end
end
