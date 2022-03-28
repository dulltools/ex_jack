defmodule ExJack.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_jack,
      version: "0.1.0",
      elixir: "~> 1.13",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      # rustler_crates: rustler_crates(),

      # compilers: [:elixir_make] ++ Mix.compilers(),
      # make_cwd: "c_src",
      deps: deps()
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
end
