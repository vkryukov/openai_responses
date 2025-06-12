defmodule OpenAI.Responses.MixProject do
  use Mix.Project

  def project do
    [
      app: :openai_responses,
      version: "0.4.2",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir client for OpenAI Responses API",
      package: package(),
      docs: docs(),

      # Project metadata
      name: "OpenAI.Responses",
      source_url: "https://github.com/vkryukov/openai_responses"
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
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:jaxon, "~> 2.0"},
      {:decimal, "~> 2.0"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/vkryukov/openai_responses"},
      maintainers: ["Victor Kryukov"],
      files: ~w(lib priv .formatter.exs mix.exs README* readme* LICENSE*
                      license* CHANGELOG* changelog* src usage-rules.md)
    ]
  end

  defp docs do
    [
      # Set README.md as the main page
      main: "readme",

      # Include documentation files
      extras: [
        "README.md",
        "CHANGELOG.md",
        "tutorial.livemd"
      ],

      # Group documentation sections
      groups_for_extras: [
        Guides: ["README.md", "CHANGELOG.md"],
        "Interactive Tutorials": ~r/\.livemd$/
      ],

      # Organize modules in the sidebar
      groups_for_modules: [
        "Main API": [
          OpenAI.Responses
        ],
        "Supporting Modules": [
          OpenAI.Responses.Response,
          OpenAI.Responses.Stream,
          OpenAI.Responses.Schema,
          OpenAI.Responses.Pricing
        ]
      ]
    ]
  end
end
