defmodule Goatmire2026Workshop.MixProject do
  use Mix.Project

  def project do
    [
      app: :goatmire_2026_workshop,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Chapter 1 deps
      {:membrane_core, "~> 1.3"},
      {:membrane_file_plugin, "~> 0.17.3"},
      {:membrane_ivf_plugin, "~> 0.9.0"},
      {:membrane_transcoder_plugin, "~> 0.4.0"},
      {:membrane_mp4_plugin, "~> 0.36.9"}
    ]
  end
end
