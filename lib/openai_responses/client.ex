defmodule OpenAI.Responses.Client do
  @moduledoc """
  HTTP client for the OpenAI Responses API.

  This module handles the communication with OpenAI's API,
  including authentication, request formatting, and response parsing.
  """

  @api_base "https://api.openai.com/v1"
  @default_timeout 60_000

  @doc """
  Creates a new API client.

  ## Options

    * `:api_key` - Your OpenAI API key (overrides environment variable)
    * `:api_base` - The base URL for API requests (default: "https://api.openai.com/v1")
    * `:req_options` - Additional options to pass to Req
    * `:request_logger` - Optional 1-arity function to log requests. Receives the `Req.Request` struct before the request is sent.
  """
  @spec new(keyword()) :: map()
  def new(opts \\ []) do
    config = Map.new(opts)
    request_logger = Map.get(config, :request_logger)

    api_key =
      case {Map.get(config, :api_key), System.get_env("OPENAI_API_KEY")} do
        {key, _} when is_binary(key) and key != "" ->
          key

        {nil, key} when is_binary(key) and key != "" ->
          key

        {nil, nil} ->
          raise "OpenAI API key not provided. Set the OPENAI_API_KEY environment variable or pass :api_key in the config."

        _ ->
          raise "Invalid OpenAI API key provided."
      end

    api_base = Map.get(config, :api_base, @api_base)
    req_options = Map.get(config, :req_options, [])

    # Base options including a default 60-second receive timeout
    base_req_options = [
      base_url: api_base,
      auth: {:bearer, api_key},
      json: true,
      receive_timeout: @default_timeout
    ]

    # User-provided req_options will override the base options
    req = Req.new(base_req_options ++ req_options)

    # Add custom request logger step if provided and valid
    if is_function(request_logger, 1) do
      Req.Request.prepend_request_steps(req,
        custom_request_logger: fn request ->
          request_logger.(request)
          request
        end
      )
    else
      req
    end
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

  Uses Req's built-in streaming capabilities. This implementation
  creates a proper Elixir Stream that processes events as they
  arrive from the API.

  ## Parameters

    * `client` - The client from `new/1`
    * `path` - The API path (e.g., "/responses")
    * `body` - The request body

  ## Returns

    * A stream of events that can be processed in real-time
  """
  @spec stream(map(), String.t(), map()) :: Enumerable.t()
  def stream(client, path, body) do
    pid = self()
    ref = make_ref()

    Stream.resource(
      fn ->
        Task.async(fn ->
          options = [
            json: body,
            into: fn {:data, data}, {req, resp} ->
              # Process each chunk of data as it arrives
              events = parse_sse_events(data)

              # Send each event to the calling process
              Enum.each(events, fn event ->
                send(pid, {ref, event})
              end)

              {:cont, {req, resp}}
            end
          ]

          # Make the request with streaming enabled
          Req.post(client, [url: path] ++ options)

          # Signal that we're done
          send(pid, {ref, :done})
        end)
      end,
      fn task ->
        # Process events as they arrive from the task
        receive do
          {^ref, :done} ->
            {:halt, task}

          {^ref, event} ->
            {[event], task}
        after
          # Timeout after 30 seconds of inactivity
          @default_timeout ->
            Task.shutdown(task, :brutal_kill)
            {:halt, task}
        end
      end,
      fn task ->
        # Clean up the task when we're done
        Task.shutdown(task, :brutal_kill)
      end
    )
  end

  # Parse Server-Sent Events format
  defp parse_sse_events(data) do
    data
    |> String.split("\n\n")
    |> Stream.filter(&(&1 != ""))
    |> Stream.map(&parse_sse_event/1)
    |> Stream.filter(&(&1 != nil))
    |> Enum.to_list()
  end

  defp parse_sse_event(event_str) do
    lines = String.split(event_str, "\n")

    event_type = get_event_field(lines, "event: ")
    data = get_event_field(lines, "data: ")

    case {event_type, data} do
      {nil, _} ->
        nil

      {_, nil} ->
        nil

      {_type, data} ->
        case Jason.decode(data) do
          # Keep the original "type" field from parsed data
          {:ok, parsed} -> parsed
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
