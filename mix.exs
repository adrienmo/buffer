defmodule Buffer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :buffer,
      version: "0.0.1",
      elixir: "~> 1.2",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: [],
      package: package,
      name: "buffer",
      source_url: "https://github.com/adrienmo/buffer",
      description: """
      Provide read and write buffers for Elixir
      """
    ]
  end

  def application do
    [applications: []]
  end

  defp package do
    [
      maintainers: ["Adrien Moreau"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/adrienmo/buffer"}
    ]
  end
end
