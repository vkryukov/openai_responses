# OpenAI.Responses

A simple Elixir client for the OpenAI Responses API, built on top of [Req](https://github.com/wojtekmach/req).

## Installation

Add `openai_responses` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:openai_responses, "~> 0.1.0"}
  ]
end
```

## Configuration

Set your OpenAI API key using one of these methods:

```elixir
# 1. Using environment variable (recommended)
System.put_env("OPENAI_API_KEY", "your-api-key")

# 2. Passing directly to functions
OpenAI.Responses.create("gpt-4o", "Hello", api_key: "your-api-key")

# 3. Creating a custom client
client = OpenAI.Responses.Client.new(api_key: "your-api-key")
OpenAI.Responses.create("gpt-4o", "Hello", client: client)
```

## Basic Usage

### Creating a Simple Response

```elixir
{:ok, response} = OpenAI.Responses.create("gpt-4o", "Write a haiku about programming")

# Extract the text output
text = OpenAI.Responses.Helpers.output_text(response)
IO.puts(text)

# Check token usage
token_usage = OpenAI.Responses.Helpers.token_usage(response)
IO.inspect(token_usage)
```

### Using Tools and Options

```elixir
{:ok, response} = OpenAI.Responses.create(
  "gpt-4o",
  "What's the weather like in Paris?",
  tools: [%{type: "web_search_preview"}],
  temperature: 0.7
)

text = OpenAI.Responses.Helpers.output_text(response)
IO.puts(text)
```

### Structured Input

```elixir
# Create a structured input with helper function
input_message = OpenAI.Responses.Helpers.create_input_message(
  "What is in this image?", 
  "https://example.com/image.jpg"
)

{:ok, response} = OpenAI.Responses.create("gpt-4o", [input_message])

# With local images (automatically encoded to Base64)
input_message = OpenAI.Responses.Helpers.create_input_message(
  "Describe these images",
  ["path/to/image1.jpg", "path/to/image2.jpg"],
  detail: "high"  # Optional detail level
)

{:ok, response} = OpenAI.Responses.create("gpt-4o", [input_message])

# Or manually create the structured input
input = [
  %{
    "role" => "user",
    "content" => [
      %{"type" => "input_text", "text" => "What is in this image?"},
      %{
        "type" => "input_image",
        "image_url" => "https://example.com/image.jpg"
      }
    ]
  }
]

{:ok, response} = OpenAI.Responses.create("gpt-4o", input)
```

### Streaming Responses

```elixir
# Get a stream of events (returns an Enumerable)
stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")

# Iterate over raw events as they arrive (true streaming)
stream 
|> Stream.each(&IO.inspect/1) 
|> Stream.run()

# Print text deltas as they arrive (real-time output)
stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
text_stream = OpenAI.Responses.text_deltas(stream)

# This preserves streaming behavior (one chunk at a time)
text_stream
|> Stream.each(fn delta -> 
  IO.write(delta)
  IO.flush()  # Ensure output is displayed immediately
end)
|> Stream.run()
IO.puts("")   # Add a newline at the end

# Create a typing effect
stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
text_stream = OpenAI.Responses.text_deltas(stream)

text_stream
|> Stream.each(fn delta -> 
  IO.write(delta)
  IO.flush()
  Process.sleep(10)  # Add delay for typing effect
end)
|> Stream.run()
IO.puts("")

# Collect a complete response from a stream
stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
response = OpenAI.Responses.collect_stream(stream)

# Work with the collected response
text = OpenAI.Responses.Helpers.output_text(response)
IO.puts(text)
```

### Other Operations

```elixir
# Get a specific response by ID
{:ok, response} = OpenAI.Responses.get("resp_123")

# Delete a response
{:ok, result} = OpenAI.Responses.delete("resp_123")

# List input items for a response
{:ok, items} = OpenAI.Responses.list_input_items("resp_123")
```

## Helper Functions

The `OpenAI.Responses.Helpers` module provides utility functions for working with responses:

```elixir
# Extract text from a response
text = OpenAI.Responses.Helpers.output_text(response)

# Get token usage information
usage = OpenAI.Responses.Helpers.token_usage(response)

# Check response status
status = OpenAI.Responses.Helpers.status(response)

# Check for refusal
if OpenAI.Responses.Helpers.has_refusal?(response) do
  refusal_message = OpenAI.Responses.Helpers.refusal_message(response)
  IO.puts("Request was refused: #{refusal_message}")
end
```

## Documentation

For more detailed documentation, run `mix docs` to generate full API documentation.

## License

MIT