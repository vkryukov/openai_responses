defmodule OpenaiResponses.MixProject do
  use Mix.Project

  def project do
    [
      app: :openai_responses,
      version: "0.3.2",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir client for OpenAI Responses API",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:decimal, "~> 2.0"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/vkryukov/openai_responses"},
      maintainers: ["Victor Kryukov"],
      description: "Elixir client for OpenAI Responses API"
    ]
  end

  defp docs do
    [
      # Set README.md as the default page
      main: "readme",
      # Define the structure of documentation
      extras: [
        "README.md",
        "docs/structured_output.md",
        "notebooks/tutorial.livemd"
      ],
      # Group documentation sections
      groups_for_extras: [
        Guides: ["README.md", "docs/structured_output.md"],
        "Interactive Tutorials": ~r/\.livemd$/
      ],
      # Order of modules in sidebar
      groups_for_modules: [
        "Client API": [
          OpenAI.Responses
        ],
        "Schema Definition": [
          OpenAI.Responses.Schema
        ],
        Utilities: [
          OpenAI.Responses.Stream,
          OpenAI.Responses.Helpers,
          OpenAI.Responses.Client,
          OpenAI.Responses.Config,
          OpenAI.Responses.Types
        ]
      ]
    ]
  end
end
