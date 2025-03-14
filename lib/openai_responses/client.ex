defmodule OpenAI.Responses.Client do
  @moduledoc """
  HTTP client for the OpenAI Responses API.
  
  This module handles the communication with OpenAI's API,
  including authentication, request formatting, and response parsing.
  """
  
  alias OpenAI.Responses.Config
  
  @api_base "https://api.openai.com/v1"
  
  @doc """
  Creates a new API client.
  
  ## Options
  
    * `:api_key` - Your OpenAI API key (overrides environment variable)
    * `:api_base` - The base URL for API requests (default: "https://api.openai.com/v1")
    * `:req_options` - Additional options to pass to Req
  """
  @spec new(keyword()) :: map()
  def new(opts \\ []) do
    config = Config.new(opts)
    api_key = Config.api_key(config)
    api_base = Config.get(config, :api_base, @api_base)
    req_options = Config.get(config, :req_options, [])
    
    Req.new([
      base_url: api_base,
      auth: {:bearer, api_key},
      json: true
    ] ++ req_options)
  end
  
  @doc """
  Makes a request to the OpenAI API.
  
  ## Parameters
  
    * `client` - The client from `new/1`
    * `method` - The HTTP method (:get, :post, :delete, etc.)
    * `path` - The API path (e.g., "/responses")
    * `body` - The request body (for POST, PUT, etc.)
    * `query` - Query parameters
  
  ## Returns
  
    * `{:ok, response}` - On success
    * `{:error, error}` - On failure
  """
  @spec request(map(), atom(), String.t(), map() | nil, map()) :: {:ok, map()} | {:error, any()}
  def request(client, method, path, body \\ nil, query \\ %{}) do
    result = Req.request(client, method: method, url: path, json: body, params: query)
    
    case result do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}
      {:ok, %{status: _status, body: %{"error" => error}}} ->
        {:error, error}
      {:ok, %{status: status}} ->
        {:error, "Unexpected status code: #{status}"}
      {:error, error} ->
        {:error, error}
    end
  end
  
  @doc """
  Streams a response from the OpenAI API.
  
  ## Parameters
  
    * `client` - The client from `new/1`
    * `path` - The API path (e.g., "/responses")
    * `body` - The request body
  
  ## Returns
  
    * A stream of events
  """
  @spec stream(map(), String.t(), map()) :: Enumerable.t()
  def stream(client, path, body) do
    client = Req.merge(client, raw: true)
    
    Stream.resource(
      fn -> start_stream(client, path, body) end,
      &process_stream/1,
      &end_stream/1
    )
  end
  
  defp start_stream(client, path, body) do
    case Req.post(client, url: path, json: body) do
      {:ok, resp = %{status: status}} when status in 200..299 ->
        {:ok, resp}
      error ->
        {:error, error}
    end
  end
  
  defp process_stream({:error, error}), do: {:halt, error}
  defp process_stream({:ok, resp}) do
    case :hackney.stream_body(resp.raw.ref) do
      {:ok, data} ->
        events = parse_sse_events(data)
        {events, {:ok, resp}}
      :done ->
        {:halt, {:ok, resp}}
      {:error, error} ->
        {:halt, {:error, error}}
    end
  end
  
  defp end_stream({:ok, resp}) do
    :hackney.close(resp.raw.ref)
  end
  defp end_stream(_), do: :ok
  
  defp parse_sse_events(data) do
    data
    |> String.split("\n\n")
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&parse_sse_event/1)
    |> Enum.filter(&(&1 != nil))
  end
  
  defp parse_sse_event(event_str) do
    lines = String.split(event_str, "\n")
    
    event_type = get_event_field(lines, "event: ")
    data = get_event_field(lines, "data: ")
    
    case {event_type, data} do
      {nil, _} -> nil
      {_, nil} -> nil
      {type, data} ->
        case Jason.decode(data) do
          {:ok, parsed} -> Map.put(parsed, "event", type)
          _ -> nil
        end
    end
  end
  
  defp get_event_field(lines, prefix) do
    Enum.find_value(lines, fn line ->
      if String.starts_with?(line, prefix) do
        String.replace(line, prefix, "", global: false)
      else
        nil
      end
    end)
  end
end