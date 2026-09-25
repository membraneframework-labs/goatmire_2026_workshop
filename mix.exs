defmodule Goatmire2026Workshop.MixProject do
  use Mix.Project

  def project do
    [
      app: :goatmire_2026_workshop,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Goatmire2026Workshop.Application, []}
    ]
  end

  defp deps do
    [
      # Chapter 1 deps
      {:membrane_core, "~> 1.3"},
      {:membrane_file_plugin, "~> 0.17.4"},
      {:membrane_ivf_plugin, "~> 0.9.0"},
      {:membrane_transcoder_plugin, "~> 0.5.0"},
      {:membrane_mp4_plugin, "~> 0.36.9"},
      # Chapter 3 deps
      {:membrane_realtimer_plugin, "~> 0.11.1"},
      {:membrane_sdl_plugin, "~> 0.18.8"},
      {:membrane_portaudio_plugin, "~> 0.19.6"},
      {:membrane_raw_audio_parser_plugin, "~> 0.5.0"},
      # Chapter 4 deps
      {:boombox, "~> 0.3.0"},
      {:bandit, "~> 1.12"}
    ]
  end
end
