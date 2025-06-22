defmodule OpenAI.Responses.Stream do
  @moduledoc """
  Streaming functionality for the Responses library.

  This module provides functions for streaming responses from the OpenAI API,
  allowing you to process data as it arrives rather than waiting for the complete response.

  ## Stream Processing Helpers

  For processing streamed data, use these helpers:

    * `text_deltas/1` - Extracts text content from event streams
    * `json_events/1` - Extracts JSON parsing events from response streams

  ## Examples

      # Extract text from streaming response
      text = Responses.stream(input: "Write a story")
             |> Responses.Stream.text_deltas()
             |> Enum.join()

      # Process JSON events directly from response stream
      Responses.stream(input: "Generate data", schema: %{name: :string})
      |> Responses.Stream.json_events()
      |> Stream.each(&IO.inspect/1)
      |> Stream.run()
  """

  alias OpenAI.Responses
  alias OpenAI.Responses.Internal

  @streaming_timeout 30_000

  @doc """
  Stream a response from the OpenAI API with a callback function.

  Takes a `callback` function that will be called for each parsed chunk of the stream.
  The callback receives results wrapped in tuples:

      {:ok, %{event: "event_type", data: %{...}}}
      # or
      {:error, reason}

  The callback should return `:ok` to continue streaming or `{:error, reason}` to stop.

  ## Options

  Accepts the same options as `Responses.create/1`, and automatically adds `stream: true` parameter.

  ## Examples

      # Simple debugging - print all results
      Responses.Stream.stream_with_callback(&IO.inspect/1, input: "Hello")

      # Process only text deltas using the delta/1 helper
      Responses.Stream.stream_with_callback(
        Responses.Stream.delta(&IO.write/1),
        input: "Write a story"
      )

      # Custom processing with error handling
      Responses.Stream.stream_with_callback(fn
        {:ok, %{event: "response.output_text.delta", data: %{"delta" => text}}} ->
          IO.write(text)
          :ok
        {:ok, %{event: "response.completed"}} ->
          IO.puts("\nStream complete!")
          :ok
        {:error, reason} ->
          IO.puts("\nStream error: \#{inspect(reason)}")
          :ok  # Continue despite error
        _ ->
          :ok
      end, input: "Tell me a joke")
  """
  def stream_with_callback(callback, options) when is_list(options) do
    # Use an agent to store the final response data
    {:ok, agent} = Agent.start_link(fn -> nil end)

    # Wrap the callback to capture response.completed event
    wrapped_callback = fn result ->
      case result do
        {:ok, %{event: "response.completed", data: data}} ->
          # Store the response data
          Agent.update(agent, fn _ -> data["response"] end)
          callback.(result)

        _ ->
          callback.(result)
      end
    end

    # Make the streaming request
    result =
      Responses.request(
        url: "/responses",
        json: Internal.prepare_payload(options |> Keyword.put(:stream, true)),
        method: :post,
        into: fn {:data, data}, {req, resp} ->
          parse_stream_chunks(wrapped_callback, data)
          {:cont, {req, resp}}
        end
      )

    # Get the stored response data and stop the agent
    response_data = Agent.get(agent, & &1)
    Agent.stop(agent)

    # Return the response with the captured data
    case {result, response_data} do
      {{:ok, _}, data} when not is_nil(data) ->
        {:ok, %OpenAI.Responses.Response{body: data}}

      _ ->
        result
    end
  end

  def stream_with_callback(callback, options) when is_map(options) do
    options = Map.to_list(options)
    stream_with_callback(callback, options)
  end

  defp parse_stream_chunks(callback, chunk) do
    chunk
    |> String.split("\n\n", trim: true)
    |> Enum.each(fn chunk ->
      result = parse_stream_chunk(chunk)
      callback.(result)
    end)

    :ok
  end

  defp parse_stream_chunk(chunk) do
    case String.split(chunk, "\n", parts: 2) do
      [event, data] ->
        if String.starts_with?(event, "event: ") && String.starts_with?(data, "data: ") do
          data = String.replace_prefix(data, "data: ", "") |> String.trim()
          event = String.replace_prefix(event, "event: ", "") |> String.trim()

          case Jason.decode(data) do
            {:ok, parsed} ->
              {:ok, %{event: event, data: parsed}}

            {:error, _} ->
              {:error, {:json_decode_error, data}}
          end
        else
          {:error, {:invalid_chunk_format, chunk}}
        end

      _ ->
        {:error, {:invalid_chunk_structure, chunk}}
    end
  end

  @doc """
  Returns a Stream that yields chunks from the OpenAI API.

  This function returns an Enumerable that yields results wrapped in tuples:
  `{:ok, chunk}` for successful chunks or `{:error, reason}` for parsing errors.

  ## Examples

      # Process all results with error handling
      Responses.stream(input: "Hello")
      |> Enum.each(fn
        {:ok, chunk} -> IO.inspect(chunk)
        {:error, reason} -> IO.puts("Error: \#{inspect(reason)}")
      end)

      # Get only text deltas, ignoring errors
      text = Responses.stream(input: "Write a story")
             |> Stream.filter(fn
               {:ok, %{event: "response.output_text.delta"}} -> true
               _ -> false
             end)
             |> Stream.map(fn {:ok, chunk} -> chunk.data["delta"] end)
             |> Enum.join()
  """
  def stream(options) when is_list(options) do
    Stream.resource(
      fn -> start_streaming(options) end,
      &stream_next/1,
      &cleanup_stream/1
    )
  end

  def stream(options) when is_map(options) do
    options = Map.to_list(options)
    stream(options)
  end

  defp start_streaming(options) do
    parent = self()
    ref = make_ref()

    # Start streaming in a separate process
    {:ok, pid} =
      Task.start_link(fn ->
        stream_with_callback(
          fn result ->
            send(parent, {ref, {:chunk, result}})
            :ok
          end,
          options
        )

        send(parent, {ref, :done})
      end)

    {parent, ref, pid}
  end

  defp stream_next({_parent, ref, _pid} = state) do
    receive do
      {^ref, {:chunk, chunk}} ->
        {[chunk], state}

      {^ref, :done} ->
        {:halt, state}
    after
      @streaming_timeout ->
        {:halt, state}
    end
  end

  defp cleanup_stream({_parent, _ref, pid}) do
    Process.exit(pid, :kill)
  end

  @doc """
  Calls the provided function on all the text chunks received from the server.

  This helper handles the wrapped results and only processes successful text delta events.
  Errors and other events are silently ignored.

  ## Examples

      Responses.create(
        input: "Write a story",
        stream: Responses.Stream.delta(&IO.write/1)
      )
  """
  def delta(f) do
    fn
      {:ok, %{data: %{"delta" => delta}, event: "response.output_text.delta"}} ->
        f.(delta)
        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Extracts text deltas from a stream, ignoring errors and other event types.

  This helper transforms a raw event stream into a text-only stream by filtering
  for `response.output_text.delta` events and extracting their delta content.
  All errors and non-text events are silently ignored.

  ## Examples

      # Get text stream from API response
      text = Responses.stream(input: "Write a story")
             |> Responses.Stream.text_deltas()
             |> Enum.join()

      # Process text incrementally
      Responses.stream(input: "Count to 10")
      |> Responses.Stream.text_deltas()
      |> Stream.each(&IO.write/1)
      |> Stream.run()
  """
  def text_deltas(stream) do
    stream
    |> Stream.filter(fn
      {:ok, %{event: "response.output_text.delta"}} -> true
      _ -> false
    end)
    |> Stream.map(fn {:ok, %{data: %{"delta" => delta}}} -> delta end)
  end

  @doc """
  Extracts JSON parsing events from a response stream.

  This helper automatically extracts text deltas from the event stream and
  converts them into JSON parsing events using incremental parsing.

  ## Events

  Returns a Stream that yields JSON parsing events:

    * `:start_object` - Beginning of a JSON object
    * `:end_object` - End of a JSON object
    * `:start_array` - Beginning of a JSON array
    * `:end_array` - End of a JSON array
    * `{:string, value}` - A string value
    * `{:integer, value}` - An integer value
    * `{:float, value}` - A float value
    * `{:boolean, value}` - A boolean value
    * `:null` - A null value
    * `:colon` - Colon between key and value
    * `:comma` - Comma between elements

  ## Examples

      # Process JSON events directly from API response
      events = Responses.stream(
        input: "Give me 10 U.S. presidents",
        schema: %{presidents: {:array, %{name: :string, birth_year: :integer}}}
      )
      |> Responses.Stream.json_events()
      |> Enum.into([])

      # Process events as they arrive
      Responses.stream(
        input: "Generate product catalog",
        schema: %{products: {:array, %{name: :string, price: :number}}}
      )
      |> Responses.Stream.json_events()
      |> Stream.each(fn event ->
        IO.inspect(event, label: "JSON Event")
      end)
      |> Stream.run()
  """
  def json_events(stream) do
    stream
    |> text_deltas()
    |> Jaxon.Stream.from_enumerable()
    |> Stream.flat_map(& &1)
  end
end
