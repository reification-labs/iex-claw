defmodule IExClaw.MixProject do
  use Mix.Project

  def project do
    [
      app: :iex_claw,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      # Agents and docs live alongside lib/ — the soul is in the files, not
      # just the source. Keep this mix project scoped to lib/+test/ for now.
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Start with only what Elder Truman called non-negotiable (dialyxir), plus
  # credo + styler for consistency. credo_naming, tallarium_credo, and
  # openspec are deferred per Round Table 2026-04-05: "don't start strict +
  # 40 checks on day one." Add them back one at a time when earned.
  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.2", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"}
    ]
  end

  # plt_add_apps: [:mix] per Elder Truman's wisdom.
  # PLT lives in _build/ (cached in CI) instead of priv/plts/ (separate cache race).
  defp dialyzer do
    [
      plt_add_apps: [:mix]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
