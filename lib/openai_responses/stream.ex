defmodule OpenAI.Responses.Stream do
  @moduledoc """
  Utilities for working with OpenAI streaming responses.
  
  This module provides functions for transforming and consuming
  streamed responses from the OpenAI API.
  
  ## Examples
  
      # Get text deltas as they arrive
      stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
      text_stream = OpenAI.Responses.Stream.text_deltas(stream)
      
      # Print each text delta in real-time
      for delta <- text_stream do
        IO.write(delta)
        IO.flush()
      end
      
      # Collect a complete response from a stream
      stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
      response = OpenAI.Responses.Stream.collect(stream)
  """
  
  @doc """
  Creates a new stream handler for OpenAI streaming responses.
  
  This function is maintained for backward compatibility.
  For new code, use the stream transformation functions directly.
  
  ## Parameters
  
    * `stream` - The stream from OpenAI.Responses.stream/3
    * `opts` - Options for the stream handler
  
  ## Returns
  
    * A stream handler struct
  """
  @spec new(Enumerable.t(), keyword()) :: map()
  def new(stream, opts \\ []) do
    %{
      stream: stream,
      options: Map.new(opts)
    }
  end
  
  @doc """
  Extracts text deltas from a stream as they arrive.
  
  This returns a stream of text chunks that can be consumed as they arrive,
  rather than waiting for the full response.
  
  ## Parameters
  
    * `stream` - The stream from OpenAI.Responses.stream/3
  
  ## Returns
  
    * A stream of text chunks
    
  ## Examples
  
      stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
      text_stream = OpenAI.Responses.Stream.text_deltas(stream)
      
      for delta <- text_stream do
        IO.write(delta)
        IO.flush()
      end
  """
  @spec text_deltas(Enumerable.t()) :: Enumerable.t(String.t())
  def text_deltas(stream) do
    # Keeps track of whether we've seen a "completed" event
    acc = Stream.transform(stream, %{completed: false}, fn event, acc ->
      case event do
        # Delta events (streaming chunks)
        %{"type" => "response.output_text.delta", "delta" => delta} ->
          {[delta], acc}
          
        # The final text from a chunk
        %{"type" => "response.output_text.done", "text" => _text} ->
          # Skip this if we've already seen the completed response
          if acc.completed do
            {[], acc}
          else
            # We'll emit empty string to avoid duplicating the full text
            {[], acc}
          end
          
        # The completed response - mark that we've seen it but don't emit the text
        %{"type" => "response.completed"} ->
          {[], %{acc | completed: true}}
          
        # Ignore all other events
        _ ->
          {[], acc}
      end
    end)
    
    # Filter out any empty strings
    Stream.filter(acc, fn s -> s != "" end)
  end
  
  @doc """
  Extracts text chunks from a stream as they arrive (legacy function).
  
  This function is maintained for backward compatibility.
  For new code, use `text_deltas/1` instead.
  
  ## Parameters
  
    * `stream_handler` - The stream handler from new/2
  
  ## Returns
  
    * A stream of text chunks
  """
  @spec text_chunks(map()) :: Enumerable.t(String.t())
  def text_chunks(%{stream: stream}) do
    text_deltas(stream)
  end
  
  @doc """
  Transforms a stream with a callback function.
  
  ## Parameters
  
    * `stream_handler` - The stream handler from new/2
    * `callback` - The callback function to apply to each event
  
  ## Returns
  
    * A transformed stream
  """
  @spec transform(map(), function()) :: Enumerable.t()
  def transform(%{stream: stream}, callback) when is_function(callback, 1) do
    Stream.map(stream, callback)
  end
  
  @doc """
  Collects all streaming events into a final response.
  
  This is useful for consuming a stream and building a complete response object,
  similar to what would be returned by a non-streaming API call.
  
  ## Parameters
  
    * `stream` - The stream from OpenAI.Responses.stream/3
  
  ## Returns
  
    * The complete response map
    
  ## Examples
  
      stream = OpenAI.Responses.stream("gpt-4o", "Tell me a story")
      response = OpenAI.Responses.Stream.collect(stream)
      
      # Process the complete response
      text = OpenAI.Responses.Helpers.output_text(response)
      IO.puts(text)
  """
  @spec collect(Enumerable.t()) :: map()
  def collect(stream) when is_function(stream, 2) or is_list(stream) do
    Enum.reduce(stream, %{}, fn event, acc ->
      case event do
        %{"type" => "response.completed", "response" => response} ->
          response
        %{"type" => "response.created", "response" => response} ->
          Map.merge(acc, response)
        %{"type" => "response.output_item.added", "item" => item, "output_index" => index} ->
          output = Map.get(acc, "output", [])
          output = List.insert_at(output, index, item)
          Map.put(acc, "output", output)
        %{"type" => "response.output_text.done", "text" => text, "output_index" => index, "content_index" => content_index} ->
          output = Map.get(acc, "output", [])
          if index < length(output) do
            item = Enum.at(output, index)
            content = Map.get(item, "content", [])
            content = List.insert_at(content, content_index, %{"type" => "output_text", "text" => text})
            item = Map.put(item, "content", content)
            output = List.replace_at(output, index, item)
            Map.put(acc, "output", output)
          else
            acc
          end
        _ ->
          acc
      end
    end)
  end
  
  # Legacy version of collect for backward compatibility
  def collect(%{stream: stream}) do
    collect(stream)
  end
end