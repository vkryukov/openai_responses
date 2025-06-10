# OpenAI.Responses Usage Guide

This guide covers all public-facing functions of the OpenAI.Responses package for LLM agents. OpenAI.Responses is an Elixir client library for interacting with OpenAI's Large Language Models (LLMs), providing a simple and powerful interface for AI-powered text generation, structured outputs, function calling, and real-time streaming.

## Setup

```elixir
# Add to mix.exs
{:openai_responses, "~> 0.4.2"}

# Set API key via environment variable
export OPENAI_API_KEY="your-key"
```

## Main Module: OpenAI.Responses

### create/1 and create!/1
Creates a new AI response. The bang version raises on error.

```elixir
# Simple text input
{:ok, response} = Responses.create("Write a haiku")
response = Responses.create!("Write a haiku")

# With options
{:ok, response} = Responses.create(
  input: "Explain quantum physics",
  model: "o4-mini",
  temperature: 0.7,
  max_tokens: 500
)

# With structured output
response = Responses.create!(
  input: "List 3 facts",
  schema: %{facts: {:array, :string}}
)
response.parsed # => %{"facts" => ["fact1", "fact2", "fact3"]}

# With streaming callback
Responses.create(
  input: "Tell a story",
  stream: fn
    {:ok, %{event: "response.output_text.delta", data: %{"delta" => text}}} ->
      IO.write(text)
      :ok
    _ -> :ok
  end
)
```

### create/2 and create!/2
Creates follow-up responses maintaining conversation context.

```elixir
first = Responses.create!("What is Elixir?")
followup = Responses.create!(first, input: "Tell me more about its concurrency")
```

### stream/1
Returns an Enumerable stream of response chunks.

```elixir
# Stream text content
text = Responses.stream("Write a poem")
       |> Responses.Stream.text_deltas()
       |> Enum.join()

# Process stream with error handling
Responses.stream("Generate data")
|> Enum.each(fn
  {:ok, chunk} -> IO.inspect(chunk)
  {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
end)
```

### run/2 and run!/2
Automates function calling by repeatedly calling functions until completion.

```elixir
# Define functions
functions = %{
  "get_weather" => fn %{"location" => loc} ->
    "15°C in #{loc}"
  end
}

# Define tools
weather_tool = Responses.Schema.build_function(
  "get_weather",
  "Get weather for a location",
  %{location: :string}
)

# Run conversation
responses = Responses.run(
  [input: "What's the weather in Paris?", tools: [weather_tool]],
  functions
)

# Last response has final answer
final_answer = List.last(responses).text
```

### list_models/0 and list_models/1
Lists available OpenAI models with optional filtering.

```elixir
# List all models
models = Responses.list_models()

# Filter by pattern
gpt_models = Responses.list_models("gpt")
```

### request/1
Low-level API request function for custom endpoints.

```elixir
{:ok, response} = Responses.request(
  url: "/models",
  method: :get
)
```

## Response Module: OpenAI.Responses.Response

Response struct fields:
- `text` - Extracted assistant message text
- `parsed` - Parsed JSON for structured outputs
- `parse_error` - Parsing error details if any
- `function_calls` - Extracted function calls
- `body` - Raw API response body
- `cost` - Usage cost breakdown

### extract_text/1
Extracts assistant messages from response. Automatically called by create functions.

```elixir
response = Response.extract_text(response)
IO.puts(response.text)
```

### extract_json/1
Extracts structured data from JSON responses. Automatically called for structured outputs.

```elixir
response = Response.extract_json(response)
data = response.parsed # => %{"key" => "value"}
```

### extract_function_calls/1
Extracts and parses function calls. Automatically called by create functions.

```elixir
response = Response.extract_function_calls(response)
calls = response.function_calls
# => [%{name: "get_weather", call_id: "...", arguments: %{"location" => "Paris"}}]
```

### calculate_cost/1
Calculates token usage costs. Automatically called by create functions.

```elixir
response = Response.calculate_cost(response)
response.cost # => %{
#   input_cost: #Decimal<0.0001>,
#   output_cost: #Decimal<0.0002>,
#   total_cost: #Decimal<0.0003>,
#   cached_discount: #Decimal<0.0000>
# }
```

## Stream Module: OpenAI.Responses.Stream

### stream_with_callback/2
Streams responses with a callback function, returns final response.

```elixir
{:ok, response} = Stream.stream_with_callback(
  fn
    {:ok, %{event: "response.output_text.delta", data: %{"delta" => text}}} ->
      IO.write(text)
      :ok
    {:error, reason} ->
      IO.puts("Error: #{inspect(reason)}")
      :ok
    _ -> :ok
  end,
  input: "Write a story"
)
```

### stream/1
Returns an Enumerable stream for flexible processing.

```elixir
stream = Stream.stream(input: "Generate content")
# Each item is {:ok, chunk} or {:error, reason}
```

### delta/1
Helper for creating simple text streaming callbacks.

```elixir
Responses.create(
  input: "Write a story",
  stream: Stream.delta(&IO.write/1)
)
```

### text_deltas/1
Extracts only text deltas from event stream.

```elixir
text = Responses.stream("Write a poem")
       |> Stream.text_deltas()
       |> Enum.join()
```

### json_events/1
Converts stream to JSON parsing events for incremental processing.

```elixir
Responses.stream(
  input: "Generate JSON data",
  schema: %{items: {:array, %{name: :string}}}
)
|> Stream.json_events()
|> Enum.each(&IO.inspect/1)
# Yields: :start_object, {:string, "items"}, :colon, :start_array, etc.
```

## Schema Module: OpenAI.Responses.Schema

### build_output/1
Converts Elixir syntax to JSON Schema for structured outputs.

```elixir
# Simple types
schema = Schema.build_output(%{
  name: :string,
  age: :integer,
  active: :boolean
})

# With constraints
schema = Schema.build_output(%{
  email: {:string, format: "email"},
  username: {:string, pattern: "^[a-z]+$", min_length: 3},
  score: {:number, minimum: 0, maximum: 100}
})

# Arrays and nested objects
schema = Schema.build_output(%{
  tags: {:array, :string},
  addresses: {:array, %{
    street: :string,
    city: :string,
    country: :string
  }}
})

# Union types
schema = Schema.build_output(%{
  result: {:anyOf, [:string, :number, :boolean]}
})
```

### build_function/3
Creates function tool definitions for function calling.

```elixir
tool = Schema.build_function(
  "search_products",
  "Search for products by name and category",
  %{
    query: {:string, description: "Search query"},
    category: {:string, enum: ["electronics", "books", "clothing"]},
    max_results: {:integer, minimum: 1, maximum: 100, description: "Max results to return"}
  }
)

# Use with create
response = Responses.create!(
  input: "Find me some laptops",
  tools: [tool]
)
```

## Common Patterns

### Conversation with State
```elixir
# Initial response sets context
chat = Responses.create!(
  input: [
    %{role: :developer, content: "You are a helpful assistant"},
    %{role: :user, content: "Hello!"}
  ]
)

# Follow-ups maintain context
chat = Responses.create!(chat, input: "What can you help with?")
```

### Structured Data Extraction
```elixir
response = Responses.create!(
  input: "Extract contact info from: John Doe, john@example.com, +1-555-0123",
  schema: %{
    name: :string,
    email: {:string, format: "email"},
    phone: {:string, pattern: "^\\+\\d{1,3}-\\d{3}-\\d{4}$"}
  }
)

contact = response.parsed
```

### Streaming with Progress
```elixir
Responses.stream("Generate a long report")
|> Stream.with_index()
|> Stream.each(fn
  {{:ok, %{event: "response.output_text.delta", data: %{"delta" => text}}}, _i} ->
    IO.write(text)
  {{:ok, %{event: "response.completed"}}, _i} ->
    IO.puts("\n✓ Complete")
  _ -> nil
end)
|> Stream.run()
```

### Error Handling
```elixir
case Responses.create("Generate content") do
  {:ok, response} ->
    IO.puts(response.text)
    IO.puts("Cost: $#{response.cost.total_cost}")
  {:error, %{"message" => msg}} ->
    IO.puts("API Error: #{msg}")
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

## Key Points

- Default model is "gpt-4o-mini"
- All responses include automatic cost calculation
- Text extraction is idempotent (safe to call multiple times)
- Streaming callbacks should return `:ok` to continue or `{:error, reason}` to stop
- Function calling with `run/2` handles multiple rounds automatically
- Structured outputs guarantee exact schema compliance
- Use `!` versions for simpler code when errors should crash
