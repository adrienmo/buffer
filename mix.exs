defmodule Buffer.Mixfile do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim

  def project do
    [
      app: :buffer,
      version: @version,
      elixir: "~> 1.5",
      test_coverage: [tool: ExCoveralls],
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: [{:ex_doc, ">= 0.0.0", only: :dev},{:excoveralls, "~> 0.5.5", only: :test}],
      package: package(),
      name: "buffer",
      source_url: "https://github.com/adrienmo/buffer",
      elixirc_options: [warnings_as_errors: true],
      description: """
      Provide read and write buffers for Elixir
      """
    ]
  end

  def application do
    [applications: [], mod: {Buffer, []}]
  end

  defp package do
    [
      files: ~w(lib README.md LICENSE VERSION mix.exs),
      maintainers: ["Adrien Moreau"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/adrienmo/buffer"}
    ]
  end
end
