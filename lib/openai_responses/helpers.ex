defmodule OpenAI.Responses.Helpers do
  @moduledoc """
  Helper functions for working with OpenAI Responses.

  This module provides utility functions for common tasks when working
  with the OpenAI Responses API, including:

  - Extracting text and data from responses
  - Creating structured messages with images
  - Handling response status and errors

  See the individual function documentation for usage examples.
  """

  require Decimal
  alias OpenAI.Responses.Helpers.ImageHelpers

  @million Decimal.new(1_000_000)

  # Costs are per 1 million tokens, keyed by the full model name
  @model_pricing %{
    "gpt-4.5-preview-2025-02-27" => %{
      input: Decimal.new("75.00"),
      input_cached: Decimal.new("37.50"),
      output: Decimal.new("150.00")
    },
    "gpt-4o-2024-08-06" => %{
      input: Decimal.new("2.50"),
      input_cached: Decimal.new("1.25"),
      output: Decimal.new("10.00")
    },
    "gpt-4o-audio-preview-2024-12-17" => %{
      input: Decimal.new("2.50"),
      input_cached: nil,
      output: Decimal.new("10.00")
    },
    "gpt-4o-realtime-preview-2024-12-17" => %{
      input: Decimal.new("5.00"),
      input_cached: Decimal.new("2.50"),
      output: Decimal.new("20.00")
    },
    "gpt-4o-mini-2024-07-18" => %{
      input: Decimal.new("0.15"),
      input_cached: Decimal.new("0.075"),
      output: Decimal.new("0.60")
    },
    "gpt-4o-mini-audio-preview-2024-12-17" => %{
      input: Decimal.new("0.15"),
      input_cached: nil,
      output: Decimal.new("0.60")
    },
    "gpt-4o-mini-realtime-preview-2024-12-17" => %{
      input: Decimal.new("0.60"),
      input_cached: Decimal.new("0.30"),
      output: Decimal.new("2.40")
    },
    "o1-2024-12-17" => %{
      input: Decimal.new("15.00"),
      input_cached: Decimal.new("7.50"),
      output: Decimal.new("60.00")
    },
    "o1-pro-2025-03-19" => %{
      input: Decimal.new("150.00"),
      input_cached: nil,
      output: Decimal.new("600.00")
    },
    "o3-mini-2025-01-31" => %{
      input: Decimal.new("1.10"),
      input_cached: Decimal.new("0.55"),
      output: Decimal.new("4.40")
    },
    "o1-mini-2024-09-12" => %{
      input: Decimal.new("1.10"),
      input_cached: Decimal.new("0.55"),
      output: Decimal.new("4.40")
    },
    "gpt-4o-mini-search-preview-2025-03-11" => %{
      input: Decimal.new("0.15"),
      input_cached: nil,
      output: Decimal.new("0.60")
    },
    "gpt-4o-search-preview-2025-03-11" => %{
      input: Decimal.new("2.50"),
      input_cached: nil,
      output: Decimal.new("10.00")
    },
    "computer-use-preview-2025-03-11" => %{
      input: Decimal.new("3.00"),
      input_cached: nil,
      output: Decimal.new("12.00")
    },
    "chatgpt-4o-latest" => %{
      input: Decimal.new("5.00"),
      input_cached: nil,
      output: Decimal.new("15.00")
    },
    "gpt-4.1-2025-04-14" => %{
      input: Decimal.new("2.00"),
      input_cached: Decimal.new("0.50"),
      output: Decimal.new("8.00")
    },
    "gpt-4.1-mini-2025-04-14" => %{
      input: Decimal.new("0.40"),
      input_cached: Decimal.new("0.10"),
      output: Decimal.new("1.60")
    },
    "gpt-4.1-nano-2025-04-14" => %{
      input: Decimal.new("0.10"),
      input_cached: Decimal.new("0.0025"),
      output: Decimal.new("0.40")
    }
  }

  # Maps short alias name to full model name
  @model_aliases %{
    "gpt-4.5-preview" => "gpt-4.5-preview-2025-02-27",
    "gpt-4o" => "gpt-4o-2024-08-06",
    "gpt-4o-audio-preview" => "gpt-4o-audio-preview-2024-12-17",
    "gpt-4o-realtime-preview" => "gpt-4o-realtime-preview-2024-12-17",
    "gpt-4o-mini" => "gpt-4o-mini-2024-07-18",
    "gpt-4o-mini-audio-preview" => "gpt-4o-mini-audio-preview-2024-12-17",
    "gpt-4o-mini-realtime-preview" => "gpt-4o-mini-realtime-preview-2024-12-17",
    "o1" => "o1-2024-12-17",
    "o1-pro" => "o1-pro-2025-03-19",
    "o3-mini" => "o3-mini-2025-01-31",
    "o1-mini" => "o1-mini-2024-09-12",
    "gpt-4o-mini-search-preview" => "gpt-4o-mini-search-preview-2025-03-11",
    "gpt-4o-search-preview" => "gpt-4o-search-preview-2025-03-11",
    "computer-use-preview" => "computer-use-preview-2025-03-11",
    "gpt-4.1" => "gpt-4.1-2025-04-14",
    "gpt-4.1-mini" => "gpt-4.1-mini-2025-04-14",
    "gpt-4.1-nano" => "gpt-4.1-nano-2025-04-14"
  }

  @doc """
  Creates a structured message with text and optional images.

  Uses the ImageHelpers module to create a properly formatted message
  with text and images for the OpenAI Responses API. See `OpenAI.Responses.Helpers.ImageHelpers.create_message_with_images/3`
  for full documentation.

  ## Examples

      # Simple text with one image URL
      iex> input_message = OpenAI.Responses.Helpers.create_message_with_images("What is in this image?", "https://example.com/image.jpg")
      iex> {:ok, response} = OpenAI.Responses.create("gpt-4o", [input_message])

      # With a local file
      iex> input_message = OpenAI.Responses.Helpers.create_message_with_images("Describe this", "/path/to/image.jpg")

      # With multiple images and high detail
      iex> input_message = OpenAI.Responses.Helpers.create_message_with_images(
      ...>   "Compare these",
      ...>   ["image1.jpg", "image2.jpg"],
      ...>   detail: "high"
      ...> )
  """
  defdelegate create_message_with_images(text, images \\ nil, opts \\ []), to: ImageHelpers

  @doc """
  Extracts the output text from a response.

  This function navigates the response structure to find and return the generated text.
  If the response contains multiple outputs or messages, it concatenates them with newlines.

  ## Parameters

    * `response` - The response from OpenAI.Responses.create/3

  ## Returns

    * The extracted text as a string
    * An empty string if no text output is found

  ## Examples

      {:ok, response} = OpenAI.Responses.create("gpt-4o", "Write a haiku about programming")
      text = OpenAI.Responses.Helpers.output_text(response)
      # => "Fingers tap keyboard\nLogic blooms in silent code\nBugs hide in plain sight"
  """
  @spec output_text(map()) :: String.t()
  def output_text(response) do
    case response do
      %{"output" => output} when is_list(output) ->
        output
        |> Enum.map(&extract_text_from_item/1)
        |> Enum.filter(&(&1 != ""))
        |> Enum.join("\n")

      _ ->
        ""
    end
  end

  @doc """
  Gets token usage information from a response.

  ## Parameters

    * `response` - The response from OpenAI.Responses.create/3

  ## Returns

    * A map with token usage information
    * nil if no usage information is found

  ## Examples

      {:ok, response} = OpenAI.Responses.create("gpt-4o", "Write a haiku about programming")
      usage = OpenAI.Responses.Helpers.token_usage(response)
      # => %{"input_tokens" => 8, "output_tokens" => 17, "total_tokens" => 25}
  """
  @spec token_usage(map()) :: map() | nil
  def token_usage(response) do
    Map.get(response, "usage")
  end

  @doc """
  Extracts the status from a response.

  ## Parameters

    * `response` - The response from OpenAI.Responses.create/3

  ## Returns

    * The status as a string (e.g., "completed", "in_progress")
    * nil if no status is found
  """
  @spec status(map()) :: String.t() | nil
  def status(response) do
    Map.get(response, "status")
  end

  @doc """
  Checks if a response contains a refusal.

  ## Parameters

    * `response` - The response from OpenAI.Responses.create/3

  ## Returns

    * true if the response contains a refusal, false otherwise
  """
  @spec has_refusal?(map()) :: boolean()
  def has_refusal?(response) do
    case response do
      %{"output" => output} when is_list(output) ->
        Enum.any?(output, fn item ->
          case item do
            %{"content" => content} when is_list(content) ->
              Enum.any?(content, &match?(%{"type" => "refusal"}, &1))

            _ ->
              false
          end
        end)

      _ ->
        false
    end
  end

  @doc """
  Gets the refusal message if one exists.

  ## Parameters

    * `response` - The response from OpenAI.Responses.create/3

  ## Returns

    * The refusal message as a string
    * nil if no refusal is found
  """
  @spec refusal_message(map()) :: String.t() | nil
  def refusal_message(response) do
    case response do
      %{"output" => output} when is_list(output) ->
        Enum.find_value(output, fn item ->
          case item do
            %{"content" => content} when is_list(content) ->
              Enum.find_value(content, fn
                %{"type" => "refusal", "refusal" => refusal} -> refusal
                _ -> nil
              end)

            _ ->
              nil
          end
        end)

      _ ->
        nil
    end
  end

  @doc """
  Calculates the estimated cost of an OpenAI API call based on token usage.

  Uses the provided model name and token usage map to calculate the cost.
  Handles model aliases (e.g., `gpt-4o` maps to `gpt-4o-2024-08-06`).
  Applies discounts for cached input tokens where applicable.

  Costs are based on the pricing defined in `@model_pricing` (per 1 million tokens),
  which uses the full, dated model names as keys.

  ## Parameters

    * `model_name` (string) - The name of the model used (e.g., "gpt-4o", "gpt-4o-mini-2024-07-18").
    * `token_usage` (map) - The token usage map, typically from `response["usage"]`.
      Expected format: `%{ "input_tokens" => integer, "input_tokens_details" => %{"cached_tokens" => integer}, "output_tokens" => integer, ... }`

  ## Returns

    * `{:ok, Decimal.t()}` - The calculated cost as a Decimal.
    * `{:error, :unknown_model_name}` - If the model name is not found in the pricing table.
    * `{:error, :invalid_usage_format}` - If the `token_usage` map has an unexpected format.

  ## Examples

      iex> usage = %{ "input_tokens" => 1000, "input_tokens_details" => %{"cached_tokens" => 500}, "output_tokens" => 2000 }
      iex> OpenAI.Responses.Helpers.calculate_cost("gpt-4o", usage) # Using alias
      {:ok, #Decimal<0.021875>}

      iex> usage = %{ "input_tokens" => 1000, "input_tokens_details" => %{"cached_tokens" => 0}, "output_tokens" => 2000 }
      iex> OpenAI.Responses.Helpers.calculate_cost("gpt-4o-2024-08-06", usage) # Using full name
      {:ok, #Decimal<0.0225>}

      iex> usage = %{ "input_tokens" => 1000, "input_tokens_details" => %{"cached_tokens" => 500}, "output_tokens" => 2000 }
      iex> OpenAI.Responses.Helpers.calculate_cost("gpt-4o-audio-preview-2024-12-17", usage) # Model without cached input discount
      {:ok, #Decimal<0.0225>}

      iex> usage = %{ "input_tokens" => 100, "input_tokens_details" => %{"cached_tokens" => 0}, "output_tokens" => 50 }
      iex> OpenAI.Responses.Helpers.calculate_cost("unknown-model", usage)
      {:error, :unknown_model_name}
  """
  @spec calculate_cost(String.t(), map()) ::
          {:ok, Decimal.t()} | {:error, :unknown_model_name | :invalid_usage_format}
  def calculate_cost(model_name, token_usage)
      when is_binary(model_name) and is_map(token_usage) do
    # Resolve alias to full name if necessary, otherwise use the provided name
    full_model_name = Map.get(@model_aliases, model_name, model_name)

    with %{input: input_rate, input_cached: cached_rate_or_nil, output: output_rate} <-
           Map.get(@model_pricing, full_model_name),
         %{
           "input_tokens" => input_tokens,
           "input_tokens_details" => %{"cached_tokens" => cached_input_tokens},
           "output_tokens" => output_tokens
         } <- token_usage,
         true <-
           is_integer(input_tokens) and is_integer(cached_input_tokens) and
             is_integer(output_tokens) do
      non_cached_input_tokens = input_tokens - cached_input_tokens
      cached_input_rate = cached_rate_or_nil || input_rate

      non_cached_input_cost =
        Decimal.mult(Decimal.new(non_cached_input_tokens), Decimal.div(input_rate, @million))

      cached_input_cost =
        Decimal.mult(Decimal.new(cached_input_tokens), Decimal.div(cached_input_rate, @million))

      output_cost = Decimal.mult(Decimal.new(output_tokens), Decimal.div(output_rate, @million))

      total_cost = Decimal.add(non_cached_input_cost, Decimal.add(cached_input_cost, output_cost))
      {:ok, total_cost}
    else
      # Model not found in pricing
      nil -> {:error, :unknown_model_name}
      # Token usage map format is incorrect
      _ -> {:error, :invalid_usage_format}
    end
  end

  @doc """
  Calculates the estimated cost from a raw OpenAI API response map.

  Extracts the model name and usage information from the response map
  and calls `calculate_cost/2`.

  ## Parameters

    * `raw_response` (map) - The raw map returned by the OpenAI API client (e.g., Req).
      Expected format: `%{ "model" => string, "usage" => map, ... }`

  ## Returns

    * `{:ok, Decimal.t()}` - The calculated cost as a Decimal.
    * `{:error, :unknown_model_name}` - If the model name is not found in the pricing table.
    * `{:error, :invalid_response_format}` - If the `raw_response` map doesn't contain "model" or "usage".
    * `{:error, :invalid_usage_format}` - If the nested "usage" map has an unexpected format.

  ## Examples

      iex> raw_response = %{
      ...>   "model" => "gpt-4o-mini",
      ...>   "usage" => %{ "input_tokens" => 500, "input_tokens_details" => %{"cached_tokens" => 100}, "output_tokens" => 1000 },
      ...>   "output" => [...]
      ...> }
      iex> OpenAI.Responses.Helpers.calculate_cost(raw_response)
      {:ok, #Decimal<0.0006675>}

      iex> raw_response = %{"model" => "unknown-model", "usage" => %{ "input_tokens" => 100, "input_tokens_details" => %{"cached_tokens" => 0}, "output_tokens" => 50 }}
      iex> OpenAI.Responses.Helpers.calculate_cost(raw_response)
      {:error, :unknown_model_name}

      iex> raw_response = %{"model" => "gpt-4o", "usage" => %{"input_tokens" => 10}} # Incomplete usage
      iex> OpenAI.Responses.Helpers.calculate_cost(raw_response)
      {:error, :invalid_usage_format}
  """
  @spec calculate_cost(map()) ::
          {:ok, Decimal.t()}
          | {:error, :unknown_model_name | :invalid_response_format | :invalid_usage_format}
  def calculate_cost(raw_response) when is_map(raw_response) do
    with %{"model" => model, "usage" => usage} <- raw_response do
      calculate_cost(model, usage)
    else
      _ -> {:error, :invalid_response_format}
    end
  end

  # Private helpers

  defp extract_text_from_item(item) do
    case item do
      %{"type" => "message", "content" => content} when is_list(content) ->
        content
        |> Enum.map(&extract_text_content/1)
        |> Enum.filter(&(&1 != ""))
        |> Enum.join("\n")

      _ ->
        ""
    end
  end

  defp extract_text_content(content) do
    case content do
      %{"type" => "output_text", "text" => text} when is_binary(text) -> text
      _ -> ""
    end
  end
end
