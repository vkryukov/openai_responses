defmodule OpenAI.Responses do
  @moduledoc """
  Client for the OpenAI Responses API.

  This module provides functions to interact with OpenAI's Responses API,
  allowing you to create, retrieve, and manage AI-generated responses.

  ## Examples

      # Create a simple text response
      {:ok, response} = OpenAI.Responses.create("gpt-4o", "Write a haiku about programming")

      # Extract the text from the response
      text = OpenAI.Responses.Helpers.output_text(response)

      # Create a response with tools and options
      {:ok, response} = OpenAI.Responses.create("gpt-4o", "What's the weather like in Paris?",
        tools: [%{type: "web_search_preview"}],
        temperature: 0.7
      )

      # Stream a response
      stream = OpenAI.Responses.create_stream("gpt-4o", "Tell me a story")
      Enum.each(stream, fn event -> IO.inspect(event) end)
  """

  alias OpenAI.Responses.Client
  alias OpenAI.Responses.Types

  @doc ~S"""
  Creates a new response with the specified model and input.

  ## Parameters

    * `model` - The model ID to use (e.g., "gpt-4o")
    * `input` - The text prompt or structured input message
    * `opts` - Optional parameters for the request
      * `:tools` - List of tools to make available to the model
      * `:instructions` - System instructions for the model
      * `:temperature` - Sampling temperature (0.0 to 2.0)
      * `:max_output_tokens` - Maximum number of tokens to generate
      * `:stream` - Whether to stream the response
      * `:previous_response_id` - ID of a previous response for continuation
      * All other parameters supported by the API

  ## Returns

    * `{:ok, response}` - On success, returns the response
    * `{:error, error}` - On failure
  """
  @spec create(String.t(), String.t() | map() | list(), keyword()) ::
          {:ok, map()} | {:error, any()}
  def create(model, input, opts \\ []) do
    client = opts[:client] || Client.new(opts)
    payload = prepare_create_payload(model, input, opts)

    case Client.request(client, :post, "/responses", payload) do
      {:ok, response} -> {:ok, Types.response(response)}
      error -> error
    end
  end

  @doc ~S"""
  Creates a streaming response with the specified model and input.

  This function is being maintained for backward compatibility.
  New code should use `stream/3` instead.

  ## Returns

    * A stream of events representing the model's response
  """
  @spec create_stream(String.t(), String.t() | map() | list(), keyword()) :: Enumerable.t()
  def create_stream(model, input, opts \\ []) do
    stream(model, input, opts)
  end

  @doc ~S"""
  Creates a streaming response and returns a proper Enumerable stream of events.

  This function returns a stream that yields individual events as they arrive from the API,
  making it suitable for real-time processing of responses.

  ## Parameters

    * `model` - The model ID to use (e.g., "gpt-4o")
    * `input` - The text prompt or structured input message
    * `opts` - Optional parameters for the request (same as `create/3`)

  ## Examples

      # Print each event as it arrives
      stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
      Enum.each(stream, &IO.inspect/1)

      # Process text deltas in real-time
      stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
      text_stream = OpenAI.Responses.Stream.text_deltas(stream)

      # This preserves streaming behavior (one chunk at a time)
      text_stream
      |> Stream.each(fn delta ->
        IO.write(delta)
      end)
      |> Stream.run()

  ## Returns

    * An Enumerable stream that yields events as they arrive
  """
  @spec stream(String.t(), String.t() | map() | list(), keyword()) :: Enumerable.t()
  def stream(model, input, opts \\ []) do
    client = opts[:client] || Client.new(opts)
    payload = prepare_create_payload(model, input, Keyword.put(opts, :stream, true))

    Client.stream(client, "/responses", payload)
  end

  @doc ~S"""
  Retrieves a specific response by ID.

  ## Parameters

    * `response_id` - The ID of the response to retrieve
    * `opts` - Optional parameters for the request
      * `:include` - Additional data to include in the response

  ## Returns

    * `{:ok, response}` - On success, returns the response
    * `{:error, error}` - On failure
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def get(response_id, opts \\ []) do
    client = opts[:client] || Client.new(opts)
    query = if opts[:include], do: %{include: opts[:include]}, else: %{}

    case Client.request(client, :get, "/responses/#{response_id}", nil, query) do
      {:ok, response} -> {:ok, Types.response(response)}
      error -> error
    end
  end

  @doc ~S"""
  Deletes a specific response by ID.

  ## Parameters

    * `response_id` - The ID of the response to delete
    * `opts` - Optional parameters for the request

  ## Returns

    * `{:ok, result}` - On success, returns deletion confirmation
    * `{:error, error}` - On failure
  """
  @spec delete(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def delete(response_id, opts \\ []) do
    client = opts[:client] || Client.new(opts)

    Client.request(client, :delete, "/responses/#{response_id}")
  end

  @doc ~S"""
  Lists input items for a specific response.

  ## Parameters

    * `response_id` - The ID of the response
    * `opts` - Optional parameters for the request
      * `:before` - List input items before this ID
      * `:after` - List input items after this ID
      * `:limit` - Number of objects to return (1-100)
      * `:order` - Sort order ("asc" or "desc")

  ## Returns

    * `{:ok, items}` - On success, returns the input items
    * `{:error, error}` - On failure
  """
  @spec list_input_items(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  def list_input_items(response_id, opts \\ []) do
    client = opts[:client] || Client.new(opts)
    query = Map.new(for {k, v} <- opts, k in [:before, :after, :limit, :order], do: {k, v})

    Client.request(client, :get, "/responses/#{response_id}/input_items", nil, query)
  end

  @doc ~S"""
  Extracts text deltas from a streaming response.

  This is a convenience function that returns a stream of text chunks as they arrive,
  useful for real-time display of model outputs. The function ensures text is not duplicated
  in the final output.

  ## Parameters

    * `stream` - The stream from OpenAI.Responses.stream/3

  ## Returns

    * A stream of text deltas

  ## Examples

      stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
      text_stream = OpenAI.Responses.text_deltas(stream)

      # Print text deltas as they arrive (real-time output)
      text_stream
      |> Stream.each(fn delta ->
        IO.write(delta)
      end)
      |> Stream.run()
      IO.puts("")   # Add a newline at the end

      # Create a typing effect
      stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
      text_stream = OpenAI.Responses.text_deltas(stream)

      text_stream
      |> Stream.each(fn delta ->
        IO.write(delta)
        Process.sleep(10)  # Add delay for typing effect
      end)
      |> Stream.run()
  """
  @spec text_deltas(Enumerable.t()) :: Enumerable.t(String.t())
  def text_deltas(stream) do
    OpenAI.Responses.Stream.text_deltas(stream)
  end

  @doc ~S"""
  Collects a complete response from a streaming response.

  This is a convenience function that consumes a stream and returns a complete response,
  similar to what would be returned by the non-streaming API. All events are processed
  and combined into a final response object.

  ## Parameters

    * `stream` - The stream from OpenAI.Responses.stream/3

  ## Returns

    * The complete response map

  ## Examples

      # Get a streaming response
      stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")

      # Collect all events into a single response object
      response = OpenAI.Responses.collect_stream(stream)

      # Process the complete response
      text = OpenAI.Responses.Helpers.output_text(response)
      IO.puts(text)
  """
  @spec collect_stream(Enumerable.t()) :: map()
  def collect_stream(stream) do
    OpenAI.Responses.Stream.collect(stream)
  end

  # Private helpers

  defp prepare_create_payload(model, input, opts) do
    base = %{
      model: model,
      input: prepare_input(input)
    }

    Enum.reduce(opts, base, fn
      {:tools, tools}, acc ->
        Map.put(acc, :tools, prepare_tools(tools))

      {key, value}, acc
      when key in [
             :instructions,
             :temperature,
             :max_output_tokens,
             :stream,
             :previous_response_id,
             :reasoning,
             :store,
             :tool_choice,
             :top_p,
             :truncation,
             :user,
             :metadata,
             :text,
             :parallel_tool_calls
           ] ->
        Map.put(acc, key, value)

      _, acc ->
        acc
    end)
  end

  defp prepare_input(input) when is_binary(input), do: input
  defp prepare_input(input), do: input

  defp prepare_tools(tools) when is_list(tools), do: tools
  defp prepare_tools(tool) when is_map(tool), do: [tool]
  defp prepare_tools(_), do: []

  @doc ~S"""
  Creates a response with structured output.

  This function is similar to `create/3` but automatically parses the response
  according to the provided schema and returns the parsed data.

  ## Parameters

    * `model` - The model ID to use (e.g., "gpt-4o")
    * `input` - The text prompt or structured input message
    * `schema` - The schema definition for structured output
    * `opts` - Optional parameters for the request
      * `:schema_name` - Optional name for the schema (default: "data")
      * All other options supported by `create/3`

  ## Returns

    * `{:ok, parsed_data}` - On success, returns the parsed data
    * `{:error, error}` - On failure

  ## Examples

      # Define a schema
      calendar_event_schema = OpenAI.Responses.Schema.object(%{
        name: :string,
        date: :string,
        participants: {:array, :string}
      })

      # Create a response with structured output
      {:ok, event} = OpenAI.Responses.parse(
        "gpt-4o",
        "Alice and Bob are going to a science fair on Friday.",
        calendar_event_schema,
        schema_name: "event"
      )

      # Access the parsed data
      IO.puts("Event: #{event["name"]} on #{event["date"]}")
      IO.puts("Participants: #{Enum.join(event["participants"], ", ")}")
  """
  @spec parse(String.t(), String.t() | map() | list(), map(), keyword()) ::
          {:ok, map()} | {:error, any()}
  def parse(model, input, schema, opts \\ []) do
    schema_name = Keyword.get(opts, :schema_name, "data")
    strict = Keyword.get(opts, :strict, true)

    # Prepare the text format with the schema according to the new API format
    text_format = %{
      format: %{
        type: "json_schema",
        name: schema_name,
        schema: schema,
        strict: strict
      }
    }

    # Construct a system message that instructs the model to extract structured data
    system_message = "Extract the #{schema_name} information."

    # Add the text format and system message to the options
    opts = opts
           |> Keyword.put(:text, text_format)
           |> Keyword.put(:instructions, system_message)

    case create(model, input, opts) do
      {:ok, response} ->
        # Extract the parsed data from the response
        case extract_parsed_data(response) do
          {:ok, data} -> {:ok, data}
          {:error, error} -> {:error, error}
        end

      error ->
        error
    end
  end

  @doc ~S"""
  Creates a streaming response with structured output.

  This function is similar to `stream/3` but automatically parses each chunk
  according to the provided schema.

  ## Parameters

    * `model` - The model ID to use (e.g., "gpt-4o")
    * `input` - The text prompt or structured input message
    * `schema` - The schema definition for structured output
    * `opts` - Optional parameters for the request
      * `:schema_name` - Optional name for the schema (default: "data")
      * All other options supported by `stream/3`

  ## Returns

    * A stream that yields parsed data chunks

  ## Examples

      # Define a schema
      math_reasoning_schema = OpenAI.Responses.Schema.object(%{
        steps: {:array, OpenAI.Responses.Schema.object(%{
          explanation: :string,
          output: :string
        })},
        final_answer: :string
      })

      # Stream a response with structured output
      stream = OpenAI.Responses.parse_stream(
        "gpt-4o",
        "Solve 8x + 7 = -23",
        math_reasoning_schema,
        schema_name: "math_reasoning"
      )

      # Process the stream
      Enum.each(stream, fn chunk ->
        IO.inspect(chunk)
      end)
  """
  @spec parse_stream(String.t(), String.t() | map() | list(), map(), keyword()) ::
          Enumerable.t()
  def parse_stream(model, input, schema, opts \\ []) do
    schema_name = Keyword.get(opts, :schema_name, "data")
    strict = Keyword.get(opts, :strict, true)

    # Prepare the text format with the schema according to the new API format
    text_format = %{
      format: %{
        type: "json_schema",
        name: schema_name,
        schema: schema,
        strict: strict
      }
    }

    # Construct a system message that instructs the model to extract structured data
    system_message = "Extract the #{schema_name} information."

    # Add the text format and system message to the options
    opts = opts
           |> Keyword.put(:text, text_format)
           |> Keyword.put(:instructions, system_message)

    # Get the stream
    stream = stream(model, input, opts)

    # Transform the stream to extract parsed data from each chunk
    Stream.map(stream, fn chunk ->
      case extract_parsed_data_from_chunk(chunk) do
        {:ok, data} -> data
        # Return the original chunk if parsing fails
        {:error, _} -> chunk
      end
    end)
  end

  # Helper function to extract parsed data from a response
  defp extract_parsed_data(response) do
    case response do
      # Check for output_text in the new API format
      %{"output_text" => output_text} when is_binary(output_text) ->
        try do
          {:ok, Jason.decode!(output_text)}
        rescue
          e -> {:error, "Failed to parse JSON from output_text: #{inspect(e)}"}
        end

      # Check for structured output in the output array
      %{"output" => [%{"content" => [%{"type" => "output_text", "text" => json_text}]}]} ->
        try do
          {:ok, Jason.decode!(json_text)}
        rescue
          e -> {:error, "Failed to parse JSON from output content: #{inspect(e)}"}
        end

      # Check for structured output in a message content array
      %{"output" => output} when is_list(output) ->
        # Look for a message with JSON content
        Enum.find_value(output, {:error, "No parsed data found"}, fn item ->
          case item do
            %{"content" => content} when is_list(content) ->
              # Look for text content that might be JSON
              Enum.find_value(content, nil, fn
                %{"type" => "output_text", "text" => text} ->
                  try do
                    {:ok, Jason.decode!(text)}
                  rescue
                    _ -> nil
                  end
                _ -> nil
              end)

            _ ->
              nil
          end
        end)

      # Try direct content access if it's a simple response
      %{"content" => content} when is_binary(content) ->
        try do
          {:ok, Jason.decode!(content)}
        rescue
          _ -> {:error, "Content is not valid JSON"}
        end

      _ ->
        {:error, "Invalid response format"}
    end
  end

  # Helper function to extract parsed data from a stream chunk
  defp extract_parsed_data_from_chunk(chunk) do
    case chunk do
      # Handle output_text delta in the new API format
      %{"delta" => %{"output_text" => output_text}} when is_binary(output_text) and output_text != "" ->
        try do
          {:ok, Jason.decode!(output_text)}
        rescue
          _ -> {:error, "Failed to parse JSON from output_text chunk"}
        end

      # Handle structured output in delta content for output_text type
      %{"delta" => %{"content" => [%{"type" => "output_text", "text" => json_text}]}} ->
        try do
          {:ok, Jason.decode!(json_text)}
        rescue
          _ -> {:error, "Failed to parse JSON from chunk"}
        end

      # Handle any text in content array that might be JSON
      %{"delta" => %{"content" => content}} when is_list(content) ->
        # Look for text content that might be JSON
        Enum.find_value(content, {:error, "No parsed data found"}, fn
          %{"type" => "output_text", "text" => text} ->
            try do
              {:ok, Jason.decode!(text)}
            rescue
              _ -> nil
            end
          _ -> nil
        end)

      # Handle text chunks that might contain JSON
      %{"delta" => %{"content" => content}} when is_binary(content) and content != "" ->
        # We can't parse partial JSON, so we'll return an error
        # The complete JSON will be handled when the stream is collected
        {:error, "Partial content chunk"}

      _ ->
        {:error, "No parsed data in chunk"}
    end
  end
end
