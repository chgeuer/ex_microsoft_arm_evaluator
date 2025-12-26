defmodule Microsoft.ARM.Evaluator.MixProject do
  # Copyright (c) Microsoft Corporation.
  # Licensed under the MIT License.
  use Mix.Project

  def project do
    [
      app: :microsoft_arm_evaluator,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        demo: [
          include_executables_for: [:windows],
          applications: [runtime_tools: :permanent]
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:exdatauri, "~> 0.2.0"},
      {:uuid, "~> 1.1"},
      {:timex, "~> 3.7"},
      {:accessible, "~> 0.3.0"},
      {:file_system, "~> 1.0"},
      {:req, "~> 0.5"},
      {:ex_microsoft_azure_utils, github: "chgeuer/ex_microsoft_azure_utils"}
    ]
  end
end
