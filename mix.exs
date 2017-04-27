defmodule ICEDemo.Mixfile do
  use Mix.Project

  def project do
    [app: :ice_demo,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {ICEDemo.Application, []}]
  end

  defp deps do
    [{:porcelain, "~> 2.0"},
     {:romeo, "~> 0.7"},
     {:jerboa, github: "esl/jerboa"}]
  end
end
