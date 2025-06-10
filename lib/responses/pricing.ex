defmodule OpenAI.Responses.Pricing do
  @moduledoc """
  Pricing information for OpenAI models.

  Prices are in USD per million tokens, stored as Decimal values for precision.
  Source: https://platform.openai.com/docs/pricing, last updated on 2025-06-03.
  """

  # Convert pricing at compile time
  pricing_data = %{
    # gpt-4.1 models
    "gpt-4.1" => {2.00, 0.50, 8.00},
    "gpt-4.1-2025-04-14" => {2.00, 0.50, 8.00},

    # gpt-4.1-mini models
    "gpt-4.1-mini" => {0.40, 0.10, 1.60},
    "gpt-4.1-mini-2025-04-14" => {0.40, 0.10, 1.60},

    # gpt-4.1-nano models
    "gpt-4.1-nano" => {0.10, 0.025, 0.40},
    "gpt-4.1-nano-2025-04-14" => {0.10, 0.025, 0.40},

    # gpt-4.5-preview models
    "gpt-4.5-preview" => {75.00, 37.50, 150.00},
    "gpt-4.5-preview-2025-02-27" => {75.00, 37.50, 150.00},

    # gpt-4o models
    "gpt-4o" => {2.50, 1.25, 10.00},
    "gpt-4o-2024-08-06" => {2.50, 1.25, 10.00},
    "gpt-4o-2024-11-20" => {2.50, 1.25, 10.00},
    "gpt-4o-2024-05-13" => {5.00, nil, 15.00},

    # gpt-4o-audio-preview models
    "gpt-4o-audio-preview" => {2.50, nil, 10.00},
    "gpt-4o-audio-preview-2024-12-17" => {2.50, nil, 10.00},
    "gpt-4o-audio-preview-2025-06-03" => {2.50, nil, 10.00},
    "gpt-4o-audio-preview-2024-10-01" => {2.50, nil, 10.00},

    # gpt-4o-realtime-preview models
    "gpt-4o-realtime-preview" => {5.00, 2.50, 20.00},
    "gpt-4o-realtime-preview-2024-12-17" => {5.00, 2.50, 20.00},
    "gpt-4o-realtime-preview-2025-06-03" => {5.00, 2.50, 20.00},
    "gpt-4o-realtime-preview-2024-10-01" => {5.00, 2.50, 20.00},

    # gpt-4o-mini models
    "gpt-4o-mini" => {0.15, 0.075, 0.60},
    "gpt-4o-mini-2024-07-18" => {0.15, 0.075, 0.60},

    # gpt-4o-mini-audio-preview models
    "gpt-4o-mini-audio-preview" => {0.15, nil, 0.60},
    "gpt-4o-mini-audio-preview-2024-12-17" => {0.15, nil, 0.60},

    # gpt-4o-mini-realtime-preview models
    "gpt-4o-mini-realtime-preview" => {0.60, 0.30, 2.40},
    "gpt-4o-mini-realtime-preview-2024-12-17" => {0.60, 0.30, 2.40},

    # o1 models
    "o1" => {15.00, 7.50, 60.00},
    "o1-2024-12-17" => {15.00, 7.50, 60.00},
    "o1-preview-2024-09-12" => {15.00, 7.50, 60.00},

    # o1-pro models
    "o1-pro" => {150.00, nil, 600.00},
    "o1-pro-2025-03-19" => {150.00, nil, 600.00},

    # o3 models
    "o3" => {2.00, 0.50, 8.00},
    "o3-2025-04-16" => {2.00, 0.50, 8.00},

    # o4-mini models
    "o4-mini" => {1.10, 0.275, 4.40},
    "o4-mini-2025-04-16" => {1.10, 0.275, 4.40},

    # o3-mini models
    "o3-mini" => {1.10, 0.55, 4.40},
    "o3-mini-2025-01-31" => {1.10, 0.55, 4.40},

    # o1-mini models
    "o1-mini" => {1.10, 0.55, 4.40},
    "o1-mini-2024-09-12" => {1.10, 0.55, 4.40},

    # codex-mini-latest models
    "codex-mini-latest" => {1.50, 0.375, 6.00},

    # gpt-4o-mini-search-preview models
    "gpt-4o-mini-search-preview" => {0.15, nil, 0.60},
    "gpt-4o-mini-search-preview-2025-03-11" => {0.15, nil, 0.60},

    # gpt-4o-search-preview models
    "gpt-4o-search-preview" => {2.50, nil, 10.00},
    "gpt-4o-search-preview-2025-03-11" => {2.50, nil, 10.00},

    # computer-use-preview models
    "computer-use-preview" => {3.00, nil, 12.00},
    "computer-use-preview-2025-03-11" => {3.00, nil, 12.00},

    # gpt-image-1 models
    "gpt-image-1" => {5.00, 1.25, nil}
  }

  # Convert to Decimal at compile time
  @pricing pricing_data
           |> Enum.map(fn {model, {input, cached, output}} ->
             {model,
              %{
                input: if(input, do: Decimal.new(to_string(input)), else: nil),
                cached_input: if(cached, do: Decimal.new(to_string(cached)), else: nil),
                output: if(output, do: Decimal.new(to_string(output)), else: nil)
              }}
           end)
           |> Map.new()

  @doc """
  Get pricing information for a specific model.

  Returns a map with :input, :cached_input, and :output prices per million tokens as Decimal values,
  or nil if the model is not found.
  """
  def get_pricing(model) do
    Map.get(@pricing, model)
  end

  @doc """
  List all available models with pricing.
  """
  def list_models do
    Map.keys(@pricing)
  end
end
