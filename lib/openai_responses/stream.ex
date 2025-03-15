defmodule OpenAI.Responses.Stream do
  @moduledoc """
  Utilities for working with OpenAI streaming responses.
  
  This module provides functions for creating, transforming, and consuming
  streamed responses from the OpenAI API.
  """
  
  @doc """
  Creates a new stream handler for OpenAI streaming responses.
  
  ## Parameters
  
    * `stream` - The stream from OpenAI.Responses.create_stream/3
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
  Transforms a stream with a callback function.
  
  ## Parameters
  
    * `stream_handler` - The stream handler from new/2
    * `callback` - The callback function to apply to each event
  
  ## Returns
  
    * A transformed stream
  """
  @spec transform(map(), function()) :: Enumerable.t()
  def transform(%{stream: stream}, callback) when is_function(callback, 1) do
    Elixir.Stream.map(stream, callback)
  end
  
  @doc """
  Collects all streaming events into a final response.
  
  This is useful for consuming a stream and building a complete response object,
  similar to what would be returned by a non-streaming API call.
  
  ## Parameters
  
    * `stream_handler` - The stream handler from new/2
  
  ## Returns
  
    * The complete response map
  """
  @spec collect(map()) :: map()
  def collect(%{stream: stream}) do
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
  
  @doc """
  Extracts text content from a stream as it arrives.
  
  This returns a stream of text chunks that can be consumed as they arrive,
  rather than waiting for the full response.
  
  ## Parameters
  
    * `stream_handler` - The stream handler from new/2
  
  ## Returns
  
    * A stream of text chunks
  """
  @spec text_chunks(map()) :: Enumerable.t(String.t())
  def text_chunks(%{stream: stream}) do
    Stream.flat_map(stream, fn event ->
      case event do
        %{"type" => "response.output_text.delta", "delta" => delta} ->
          [delta]
        %{"type" => "response.output_text.done", "text" => text} ->
          [text]
        _ ->
          []
      end
    end)
  end
end