defmodule RTP_SSE.MixProject do
  use Mix.Project

  def project do
    [
      app: :rtp_sse,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {RTP_SSE, []}
    ]
  end

  defp deps do
    [
      {:eventsource_ex, "~> 0.0.2"},
      {:poison, "~> 3.1"},
      {:mongodb_driver, "~> 0.8.3"},
      {:destructure, "~> 0.2.3"},
      {:statistics, "~> 0.6.2"},
      {:elixir_uuid, "~> 1.2"}
    ]
  end
end
