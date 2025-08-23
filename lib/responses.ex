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
  alias OpenAI.Responses.Error

  @doc """
  Create a new response.

  When the argument is a string, it is used as the input text.
  Otherwise, the argument is expected to be a keyword list or map of options that OpenAI expects,
  such as `input`, `model`, `temperature`, `max_tokens`, etc.

  ## LLM Options Preservation with previous_response_id

  The OpenAI API always requires a model parameter, even when using `previous_response_id`.

  When using `create/1` with manual `previous_response_id`:
  - If no model is specified, the default model is used
  - LLM options (model, text, reasoning) from the previous response are NOT automatically inherited

  When using `create/2` with a Response object:
  - LLM options (model, text, reasoning) from the previous response ARE automatically inherited
  - You can override any of them by explicitly specifying different values

      # Manual previous_response_id - uses defaults if not specified
      Responses.create(input: "Hello", previous_response_id: "resp_123")

      # Manual previous_response_id - with explicit options
      Responses.create(input: "Hello", previous_response_id: "resp_123", model: "gpt-4.1")

      # Using create/2 - automatically inherits LLM options from previous response
      Responses.create(previous_response, input: "Hello")
      
      # Using create/2 - with reasoning effort preserved (requires model that supports reasoning)
      first = Responses.create!(input: "Question", model: "gpt-5-mini", reasoning: %{effort: "high"})
      followup = Responses.create!(first, input: "Follow-up")  # Inherits gpt-5-mini and high reasoning

  ## Examples

      # Using a keyword list
      Responses.create(input: "Hello", model: "gpt-4.1", temperature: 0.7)

      # Using a map
      Responses.create(%{input: "Hello", model: "gpt-4.1", temperature: 0.7})

      # String shorthand
      Responses.create("Hello")

  ## Structured Output with :schema

  Pass a `schema:` option to get structured JSON output from the model.
  The schema is defined using a simple Elixir syntax that is converted to JSON Schema format.

  Both maps and keyword lists with atom or string keys are accepted for all options:

      # Using a map with atom keys
      Responses.create(%{
        input: "Extract user info from: John Doe, username @johndoe, john@example.com",
        schema: %{
          name: :string,
          username: {:string, pattern: "^@[a-zA-Z0-9_]+$"},
          email: {:string, format: "email"}
        }
      })

      # Using a keyword list
      Responses.create(
        input: "Extract product details",
        schema: [
          product_name: :string,
          price: :number,
          in_stock: :boolean,
          tags: {:array, :string}
        ]
      )

      # Arrays at the root level (new in 0.6.0)
      Responses.create(
        input: "List 3 US presidents with facts",
        schema: {:array, %{
          name: :string,
          birth_year: :integer,
          achievements: {:array, :string}
        }}
      )
      # Returns an array directly in response.parsed

      # Mixed keys (atoms and strings) are supported
      Responses.create(%{
        "input" => "Analyze this data",
        :schema => %{
          "result" => :string,
          :confidence => :number
        }
      })

  The response will include a `parsed` field with the extracted structured data.
  See `OpenAI.Responses.Schema` for the full schema syntax documentation.

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
  def create(options) when is_list(options) or is_map(options) do
    # Extract stream callback (helper automatically checks both atom and string keys)
    stream_callback = get_option(options, :stream)

    result =
      if stream_callback do
        # Handle streaming - pass options directly
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

  # Define LLM options that should be preserved across chained responses
  @preserved_llm_options ["model", "text", "reasoning"]

  @doc """
  Create a response based on a previous response.

  This allows creating follow-up responses that maintain context from a previous response.
  The previous response's ID is automatically included in the request.

  Options can be provided as either a keyword list or a map.

  ## Preserved Options

  The following options are automatically preserved from the previous response unless explicitly overridden:
  - `model` - The model used for generation
  - `text` - Text generation settings (including verbosity)
  - `reasoning` - Reasoning settings (including effort level)

  ## Examples

      {:ok, first} = Responses.create("What is Elixir?")
      
      # Using keyword list
      {:ok, followup} = Responses.create(first, input: "Tell me more about its concurrency model")
      
      # Using map
      {:ok, followup} = Responses.create(first, %{input: "Tell me more about its concurrency model"})
      
      # With reasoning effort preserved (requires model that supports reasoning)
      {:ok, first} = Responses.create(input: "Complex question", model: "gpt-5-mini", reasoning: %{effort: "high"})
      {:ok, followup} = Responses.create(first, input: "Follow-up")  # Inherits gpt-5-mini and high reasoning effort
  """
  def create(%Response{} = previous_response, options) when is_list(options) or is_map(options) do
    # Convert to map for easier manipulation
    options_map = if is_list(options), do: Map.new(options), else: options

    # Add previous_response_id
    options_map = Map.put(options_map, :previous_response_id, previous_response.body["id"])

    # Preserve LLM options from the previous response if not explicitly provided
    options_map = preserve_llm_options(options_map, previous_response.body)

    create(options_map)
  end

  # Helper to preserve LLM options from previous response
  defp preserve_llm_options(options_map, previous_body) do
    Enum.reduce(@preserved_llm_options, options_map, fn key, acc ->
      preserve_single_option(acc, previous_body, key)
    end)
  end

  defp preserve_single_option(options_map, previous_body, key) do
    key_atom = String.to_atom(key)
    
    # Check if the option is already provided (as atom or string)
    if has_option?(options_map, key_atom) do
      options_map
    else
      # Get the value from the previous response body
      case previous_body[key] do
        nil -> options_map
        value -> Map.put(options_map, key_atom, value)
      end
    end
  end

  @doc """
  Same as `create/1` but raises an error on failure.

  Returns the response directly instead of an {:ok, response} tuple.

  ## Examples

      response = Responses.create!("Hello, world!")
      IO.puts(response.text)
  """
  def create!(options) do
    case create(options) do
      {:ok, response} -> response
      {:error, error} -> raise error
    end
  end

  @doc """
  Same as `create/2` but raises an error on failure.

  Returns the response directly instead of an {:ok, response} tuple.

  ## Examples

      first = Responses.create!("What is Elixir?")
      followup = Responses.create!(first, input: "Tell me more")
  """
  def create!(%Response{} = previous_response, options) do
    case create(previous_response, options) do
      {:ok, response} -> response
      {:error, error} -> raise error
    end
  end

  @doc """
  Stream a response from the OpenAI API as an Enumerable.

  Returns a Stream that yields chunks with `event` and `data` keys.

  Options can be provided as either a keyword list or a map.

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

      # Accumulate all text with error handling (using map)
      result = Responses.stream(%{input: "Explain quantum physics"})
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

  def stream(options) when is_map(options) do
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

  - `options` - Keyword list or map of options to pass to `create/1`
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

      # Run the conversation (with keyword list)
      responses = Responses.run(
        [input: "What's the weather in Paris and what time is it?",
         tools: [weather_tool, time_tool]],
        functions
      )

      # Or with map
      responses = Responses.run(
        %{input: "What's the weather in Paris and what time is it?",
          tools: [weather_tool, time_tool]},
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

  def run(options, functions)
      when is_map(options) and (is_map(functions) or is_list(functions)) do
    # Convert map to list for processing
    options_list = Map.to_list(options)
    run(options_list, functions)
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
      call = map_convert_atom_keys_to_strings(call)
      function_name = call["name"]
      function = get_function(functions, function_name)

      result =
        case function do
          nil ->
            "Error: Function '#{function_name}' not found"

          f when is_function(f, 1) ->
            try do
              f.(call["arguments"])
            rescue
              e -> "Error calling function '#{function_name}': #{Exception.message(e)}"
            end

          _ ->
            "Error: Invalid function for '#{function_name}'"
        end

      %{
        type: "function_call_output",
        call_id: call["call_id"],
        output: result
      }
    end)
  end

  defp map_convert_atom_keys_to_strings(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
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

      {:ok, resp = %Req.Response{}} ->
        {:error, Error.from_response(resp)}

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

  # Helper to get option from either keyword list or map, checking both atom and string keys
  defp get_option(options, key) when is_list(options) and is_atom(key) do
    # Keyword lists only support atom keys
    Keyword.get(options, key)
  end

  defp get_option(options, key) when is_list(options) and is_binary(key) do
    # Try to convert string to atom for keyword list lookup
    try do
      Keyword.get(options, String.to_existing_atom(key))
    rescue
      ArgumentError -> nil
    end
  end

  defp get_option(options, key) when is_map(options) and is_atom(key) do
    # Check both atom and string versions of the key
    Map.get(options, key) || Map.get(options, to_string(key))
  end

  defp get_option(options, key) when is_map(options) and is_binary(key) do
    # Check string key first, then try atom version
    case Map.get(options, key) do
      nil ->
        try do
          Map.get(options, String.to_existing_atom(key))
        rescue
          ArgumentError -> nil
        end

      value ->
        value
    end
  end

  # Helper to check if option exists (for any key variant)
  defp has_option?(options, key) when is_atom(key) do
    get_option(options, key) != nil || get_option(options, to_string(key)) != nil
  end
end
