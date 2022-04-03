defmodule ExJack.MixProject do
  use Mix.Project

  @source_url "https://github.com/fraihaav/ex_jack"
  @version "0.28.3"

  def project do
    [
      app: :ex_jack,
      version: @version,
      source_url: @source_url,
      elixir: "~> 1.13",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      deps: deps(),
      docs: docs(),
      package: package(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:elixir_make, "~> 0.6", runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.22.1", only: :dev, runtime: false},
      {:benchee, "~> 1.0", only: [:test, :dev]},
      {:rustler, github: "hansihe/rustler", sparse: "rustler_mix"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "LICENSE",
        "CHANGELOG.md"
      ],
      source_ref: "v#{@version}",
      source_url: @source_url,
      groups_for_modules: [],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Adrian Fraiha"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/ex_jack/changelog.html"
      }
    ]
  end
end
