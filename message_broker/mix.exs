defmodule MessageBroker.MixProject do
  use Mix.Project

  def project do
    [
      app: :message_broker,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MessageBroker, []}
    ]
  end

  defp deps do
    [
      {:poison, "~> 3.1"},
      {:destructure, "~> 0.2.3"}
    ]
  end
end
