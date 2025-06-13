defmodule OpenAI.Responses do
  @moduledoc """
  Client for OpenAI Responses API.

  This module provides a simple interface for creating AI responses with support for:
  - Text and structured output generation
  - Streaming responses with Server-Sent Events (SSE)
  - Automatic cost calculation for all API calls
  - JSON Schema-based structured outputs

  ## Available Functions

  - `create/1` and `create/2` - Create AI responses (synchronous or streaming)
  - `create!/1` and `create!/2` - Same as create but raises on error
  - `run/2` and `run!/2` - Run conversations with automatic function calling
  - `call_functions/2` - Execute function calls and format results for the API
  - `stream/1` - Stream responses as an Enumerable
  - `list_models/0` and `list_models/1` - List available OpenAI models
  - `request/1` - Low-level API request function

  ## Configuration

  Set your OpenAI API key via:
  - Environment variable: `OPENAI_API_KEY`
  - Application config: `config :openai_responses, :openai_api_key, "your-key"`

  ## Examples

  See the [tutorial](tutorial.livemd) for comprehensive examples and usage patterns.
  """

  @default_receive_timeout 60_000

  alias OpenAI.Responses
  alias OpenAI.Responses.Response
  alias OpenAI.Responses.Internal

  @doc """
  Create a new response.

  When the argument is a string, it is used as the input text.
  Otherwise, the argument is expected to be a keyword list of options that OpenAI expects,
  such as `input`, `model`, `temperature`, `max_tokens`, etc.

  ## Streaming

  Pass a `stream:` option with a callback function to stream the response.
  The callback receives results wrapped in `{:ok, chunk}` or `{:error, reason}` tuples:

      Responses.create(
        input: "Write a story",
        stream: fn
          {:ok, %{event: "response.output_text.delta", data: %{"delta" => text}}} ->
            IO.write(text)
            :ok
          {:error, reason} ->
            IO.puts("Stream error: \#{inspect(reason)}")
            :ok  # Continue despite errors
          _ ->
            :ok
        end
      )

  The callback should return `:ok` to continue or `{:error, reason}` to stop the stream.

  For simpler text streaming, use the `delta/1` helper:

      Responses.create(
        input: "Write a story",
        stream: Responses.Stream.delta(&IO.write/1)
      )

  If no model is specified, the default model is used.
  """
  def create(options) when is_list(options) do
    {stream_callback, options} = Keyword.pop(options, :stream)

    result =
      if stream_callback do
        # Handle streaming
        Responses.Stream.stream_with_callback(stream_callback, options)
      else
        # Regular non-streaming request
        request(url: "/responses", json: Internal.prepare_payload(options), method: :post)
      end

    # Process the response
    with {:ok, response} <- result do
      {:ok, process_response(response)}
    end
  end

  def create(input) when is_binary(input) do
    create(input: input)
  end

  @doc """
  Create a response based on a previous response.

  This allows creating follow-up responses that maintain context from a previous response.
  The previous response's ID is automatically included in the request.

  ## Examples

      {:ok, first} = Responses.create("What is Elixir?")
      {:ok, followup} = Responses.create(first, input: "Tell me more about its concurrency model")
  """
  def create(%Response{} = previous_response, options) do
    options = options |> Keyword.put(:previous_response_id, previous_response.body["id"])
    
    # Preserve the model from the previous response if not explicitly provided
    options =
      if Keyword.has_key?(options, :model) do
        options
      else
        case previous_response.body["model"] do
          nil -> options
          model -> Keyword.put(options, :model, model)
        end
      end
    
    create(options)
  end

  @doc """
  Same as `create/1` but raises an error on failure.

  Returns the response directly instead of an {:ok, response} tuple.

  ## Examples

      response = Responses.create!("Hello, world!")
      IO.puts(response.text)
  """
  def create!(options) do
    {:ok, response} = create(options)
    response
  end

  @doc """
  Same as `create/2` but raises an error on failure.

  Returns the response directly instead of an {:ok, response} tuple.

  ## Examples

      first = Responses.create!("What is Elixir?")
      followup = Responses.create!(first, input: "Tell me more")
  """
  def create!(%Response{} = previous_response, options) do
    {:ok, response} = create(previous_response, options)
    response
  end

  @doc """
  Stream a response from the OpenAI API as an Enumerable.

  Returns a Stream that yields chunks with `event` and `data` keys.

  ## Examples

      # Stream and handle all results
      for result <- Responses.stream("Tell me a story") do
        case result do
          {:ok, chunk} -> IO.inspect(chunk)
          {:error, reason} -> IO.puts("Error: \#{inspect(reason)}")
        end
      end

      # Process only text deltas, ignoring errors
      Responses.stream("Write a poem")
      |> Stream.filter(fn
        {:ok, %{event: "response.output_text.delta"}} -> true
        _ -> false
      end)
      |> Stream.map(fn {:ok, chunk} -> chunk.data["delta"] end)
      |> Enum.each(&IO.write/1)

      # Accumulate all text with error handling
      result = Responses.stream(input: "Explain quantum physics")
               |> Enum.reduce(%{text: "", errors: []}, fn
                 {:ok, %{event: "response.output_text.delta", data: %{"delta" => delta}}}, acc ->
                   %{acc | text: acc.text <> delta}
                 {:error, reason}, acc ->
                   %{acc | errors: [reason | acc.errors]}
                 _, acc ->
                   acc
               end)
  """
  def stream(options) when is_list(options) do
    Responses.Stream.stream(options)
  end

  def stream(input) when is_binary(input) do
    stream(input: input)
  end

  @doc """
  List available models.

  Accepts an optional `match` string to filter by model ID.
  """
  def list_models(match \\ "") do
    {:ok, response} = request(url: "/models")

    response.body["data"]
    |> Enum.filter(&(&1["id"] =~ match))
  end

  @doc """
  Run a conversation with automatic function calling.

  This function automates the process of handling function calls by repeatedly calling the
  provided functions and feeding their results back to the model until a final response
  without function calls is received.

  ## Parameters

  - `options` - Keyword list of options to pass to `create/1`
  - `functions` - A map or keyword list where:
    - Keys are function names (as atoms or strings)
    - Values are functions that accept the parsed arguments and return the result

  ## Returns

  Returns a list of all responses generated during the conversation, in chronological order.
  The last response in the list will be the final answer without function calls.

  ## Examples

      # Define available functions
      functions = %{
        "get_weather" => fn %{"location" => location} ->
          # Simulate weather API call
          "The weather in \#{location} is 72°F and sunny"
        end,
        "get_time" => fn %{} ->
          DateTime.utc_now() |> to_string()
        end
      }

      # Create function tools
      weather_tool = Responses.Schema.build_function(
        "get_weather",
        "Get current weather for a location",
        %{location: :string}
      )

      time_tool = Responses.Schema.build_function(
        "get_time",
        "Get the current UTC time",
        %{}
      )

      # Run the conversation
      responses = Responses.run(
        [input: "What's the weather in Paris and what time is it?",
         tools: [weather_tool, time_tool]],
        functions
      )

      # The last response contains the final answer
      final_response = List.last(responses)
      IO.puts(final_response.text)
  """
  def run(options, functions)
      when is_list(options) and (is_map(functions) or is_list(functions)) do
    case do_run(options, functions, []) do
      responses when is_list(responses) -> Enum.reverse(responses)
      error -> error
    end
  end

  defp do_run(options, functions, responses) do
    case create(options) do
      {:ok, response} ->
        handle_response(response, options, functions, responses)

      {:error, _} = error ->
        error
    end
  end

  defp do_run(%Response{} = previous_response, options, functions, responses) do
    case create(previous_response, options) do
      {:ok, response} ->
        handle_response(response, options, functions, responses)

      {:error, _} = error ->
        error
    end
  end

  defp handle_response(response, _options, functions, responses) do
    responses = [response | responses]

    case response.function_calls do
      nil ->
        # No function calls, return all responses
        responses

      [] ->
        # Empty function calls, return all responses
        responses

      calls ->
        # Process function calls and continue
        function_results = call_functions(calls, functions)

        # Continue conversation with function results using the latest response
        do_run(response, [input: function_results], functions, responses)
    end
  end

  defp get_function(functions, name) when is_map(functions) do
    Map.get(functions, name) || Map.get(functions, to_string(name))
  end

  defp get_function(functions, name) when is_list(functions) do
    name_atom =
      cond do
        is_atom(name) ->
          name

        is_binary(name) ->
          try do
            String.to_existing_atom(name)
          rescue
            ArgumentError -> nil
          end

        true ->
          nil
      end

    Keyword.get(functions, name_atom)
  end

  @doc """
  Same as `run/2` but raises an error on failure.

  Returns the list of responses directly instead of an {:ok, responses} tuple.
  """
  def run!(options, functions) do
    case run(options, functions) do
      responses when is_list(responses) -> responses
      {:error, reason} -> raise "Function calling failed: #{inspect(reason)}"
    end
  end

  @doc """
  Execute function calls from a response and format the results for the API.

  Takes the function_calls from a response and a map/keyword list of functions,
  executes each function with its arguments, and returns the formatted results
  ready to be used as input for the next API call.

  ## Parameters

  - `function_calls` - The function_calls array from a Response struct
  - `functions` - A map or keyword list where:
    - Keys are function names (as atoms or strings)
    - Values are functions that accept the parsed arguments and return the result

  ## Returns

  Returns a list of formatted function outputs suitable for use as input to `create/2`.
  
  **Important**: Function return values must be JSON-encodable. This means they should
  only contain basic types (strings, numbers, booleans, nil), lists, and maps. Tuples,
  atoms (except `true`, `false`, and `nil`), and other Elixir-specific types are not
  supported by default unless they implement the `Jason.Encoder` protocol.

  ## Examples

      # Get a response with function calls
      {:ok, response} = Responses.create(
        input: "What's the weather in Paris and what time is it?",
        tools: [weather_tool, time_tool]
      )

      # Define the actual function implementations
      functions = %{
        "get_weather" => fn %{"location" => location} ->
          # Returns a map (JSON-encodable)
          %{temperature: 22, unit: "C", location: location}
        end,
        "get_time" => fn %{} ->
          # Returns a string (JSON-encodable)
          DateTime.utc_now() |> to_string()
        end
      }

      # Execute the functions and get formatted output
      outputs = Responses.call_functions(response.function_calls, functions)
      
      # Continue the conversation with the function results
      {:ok, final_response} = Responses.create(response, input: outputs)

  ## Error Handling

  If a function is not found or raises an error, the output will contain
  an error message instead of the function result.
  """
  def call_functions(function_calls, functions)
      when is_list(function_calls) and (is_map(functions) or is_list(functions)) do
    Enum.map(function_calls, fn call ->
      function_name = call.name
      function = get_function(functions, function_name)

      result =
        case function do
          nil ->
            "Error: Function '#{function_name}' not found"

          f when is_function(f, 1) ->
            try do
              f.(call.arguments)
            rescue
              e -> "Error calling function '#{function_name}': #{Exception.message(e)}"
            end

          _ ->
            "Error: Invalid function for '#{function_name}'"
        end

      %{
        type: "function_call_output",
        call_id: call.call_id,
        output: result
      }
    end)
  end

  @doc """
  Request a response from the OpenAI API.

  Used as a building block by other functions in this module.
  Accepts that same arguments as `Req.request/1`.
  You should provide `url`, `json`, `method`, and other options as needed.
  """
  def request(options) do
    req =
      Req.new(
        base_url: "https://api.openai.com/v1",
        receive_timeout: @default_receive_timeout,
        auth: {:bearer, Internal.get_api_key()}
      )
      |> Req.merge(options)

    case Req.request(req) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, %Response{body: body}}

      {:ok, %Req.Response{body: %{"error" => error}}} ->
        {:error, error}

      {_status, other} ->
        {:error, other}
    end
  end

  # Process a response by extracting text, JSON, function calls, and calculating cost
  defp process_response(response) do
    response
    |> Response.extract_json()
    |> Response.extract_function_calls()
    |> Response.calculate_cost()
  end
end
