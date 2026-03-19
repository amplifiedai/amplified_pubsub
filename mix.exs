defmodule Amplified.PubSub.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/amplified/amplified_pubsub"

  def project do
    [
      app: :amplified_pubsub,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "Amplified.PubSub",
      description: "A protocol-based PubSub abstraction for Phoenix LiveView",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:recase, "~> 0.8"},
      {:ecto, "~> 3.10", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "Amplified.PubSub",
      source_url: @source_url,
      source_ref: "v#{@version}",
      groups_for_modules: [
        "Protocol Implementations": [
          Amplified.PubSub.Protocol.Atom,
          Amplified.PubSub.Protocol.BitString,
          Amplified.PubSub.Protocol.List,
          Amplified.PubSub.Protocol.Stream,
          Amplified.PubSub.Protocol.Tuple,
          Amplified.PubSub.Protocol.Phoenix.LiveView.Socket
        ]
      ]
    ]
  end
end
