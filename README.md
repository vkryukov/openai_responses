# OpenAI.Responses

A client library for the OpenAI Responses API with automatic text extraction and cost calculation.

## Installation

Add `openai_responses` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:openai_responses, "~> 0.4.0"}
  ]
end
```

## Configuration

Set your OpenAI API key using one of these methods:

### Environment Variable
```bash
export OPENAI_API_KEY="your-api-key"
```

### Application Config
```elixir
config :openai_responses, :openai_api_key, "your-api-key"
```

## Getting Started

For a comprehensive tutorial and examples, see the [interactive tutorial](tutorial.livemd) in Livebook.

## Advanced Examples

### Simple terminal chat

```elixir
defmodule Chat do
  alias OpenAI.Responses

  def run do
    IO.puts("Simple AI Chat (type /exit or /quit to end)")
    IO.puts("=" |> String.duplicate(40))

    loop(nil)
  end

  defp loop(previous_response) do
    input = IO.gets("\nYou: ") |> String.trim()

    case input do
      cmd when cmd in ["/exit", "/quit"] ->
        IO.puts("\nGoodbye!")

      _ ->
        IO.write("\nAI: ")

        # Use previous response for context, or create new conversation
        response = if previous_response do
          # Continue conversation with context
          Responses.create!(
            previous_response,
            input: input,
            stream: Responses.Stream.delta(&IO.write/1)
          )
        else
            # First message - start new conversation
            Responses.create!(
              input: input,
              stream: Responses.Stream.delta(&IO.write/1)
            )
        end

        IO.puts("")  # Add newline after response
        loop(response)
    end
  end
end

# Run the chat
Chat.run()
```


### Streaming with Structured Output

```elixir
# Stream a JSON response with structured output
Responses.stream(
  input: "List 3 programming languages with their year of creation",
  model: "gpt-4o-mini",
  schema: %{
    languages: {:array, %{
      name: :string,
      year: :integer,
      paradigm: {:string, description: "Main programming paradigm"}
    }}
  }
)
|> Responses.Stream.json_events()
|> Enum.each(&IO.puts/1)
```

### Cost Tracking with High Precision

```elixir
{:ok, response} = Responses.create("Explain quantum computing")

# All cost values are Decimal for precision
IO.inspect(response.cost)
# => %{
#      input_cost: #Decimal<0.0004>,
#      output_cost: #Decimal<0.0008>,
#      total_cost: #Decimal<0.0012>,
#      cached_discount: #Decimal<0>
#    }

# Convert to float if needed
total_in_cents = response.cost.total_cost |> Decimal.mult(100) |> Decimal.to_float()
```

## Documentation

- [API Documentation](https://hexdocs.pm/openai_responses)
- [Interactive Tutorial](tutorial.livemd)
- [GitHub Repository](https://github.com/vkryukov/openai-responses)
