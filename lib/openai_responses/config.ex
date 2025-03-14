defmodule OpenAI.Responses.Config do
  @moduledoc """
  Configuration management for the OpenAI Responses API client.
  
  This module handles configuration options and environment variables.
  """
  
  @doc """
  Creates a new configuration map with the provided options.
  
  ## Options
  
    * `:api_key` - Your OpenAI API key (overrides environment variable)
    * `:api_base` - The base URL for API requests
    * Other options used by the client
  """
  @spec new(keyword()) :: map()
  def new(opts \\ []) do
    Map.new(opts)
  end
  
  @doc """
  Gets a value from the configuration, with an optional default.
  
  ## Parameters
  
    * `config` - The configuration map
    * `key` - The key to look up
    * `default` - The default value if the key is not found
  """
  @spec get(map(), atom(), any()) :: any()
  def get(config, key, default \\ nil) do
    Map.get(config, key, default)
  end
  
  @doc """
  Gets the API key from the configuration or environment.
  
  Looks for the API key in the following places, in order:
  1. The `:api_key` key in the config map
  2. The `OPENAI_API_KEY` environment variable
  
  ## Parameters
  
    * `config` - The configuration map
  
  ## Returns
  
    * The API key, or raises an error if not found
  """
  @spec api_key(map()) :: String.t()
  def api_key(config) do
    case {get(config, :api_key), System.get_env("OPENAI_API_KEY")} do
      {nil, nil} -> raise "OpenAI API key not provided. Set the OPENAI_API_KEY environment variable or pass :api_key in the config."
      {key, _} when is_binary(key) and key != "" -> key
      {_, key} when is_binary(key) and key != "" -> key
      _ -> raise "Invalid OpenAI API key provided."
    end
  end
end