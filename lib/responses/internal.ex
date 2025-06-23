defmodule OpenAI.Responses.Internal do
  @moduledoc false

  @default_model "gpt-4.1-mini"

  @doc """
  Prepare the payload for API requests.
  Handles schema conversion and sets default model.
  """
  def prepare_payload(options) do
    # Normalize everything to maps with string keys
    options = normalize_to_string_keys(options)
    
    {schema, options} = Map.pop(options, "schema")

    options =
      if schema do
        Map.put(options, "text", %{"format" => OpenAI.Responses.Schema.build_output(schema)})
      else
        options
      end

    Map.put_new(options, "model", @default_model)
  end

  # Normalize all input formats to maps with string keys
  defp normalize_to_string_keys(options) when is_map(options) do
    Map.new(options, fn {k, v} -> {to_string(k), normalize_value(v)} end)
  end

  defp normalize_to_string_keys(options) when is_list(options) do
    options
    |> Enum.map(fn
      {k, v} -> {to_string(k), normalize_value(v)}
      other -> raise ArgumentError, "Invalid option format: #{inspect(other)}"
    end)
    |> Map.new()
  end

  # Recursively normalize nested values
  defp normalize_value(value) when is_map(value) do
    normalize_to_string_keys(value)
  end

  defp normalize_value(value) when is_list(value) do
    # Check if it's a keyword list (has at least one tuple)
    if value != [] and is_tuple(hd(value)) do
      # Try to convert as keyword list
      try do
        normalize_to_string_keys(value)
      rescue
        # If it fails, treat as regular list
        ArgumentError -> Enum.map(value, &normalize_value/1)
      end
    else
      # Regular list - keep as array
      Enum.map(value, &normalize_value/1)
    end
  end

  defp normalize_value(value), do: value

  @doc """
  Get the API key from application config or environment variable.
  """
  def get_api_key() do
    Application.get_env(:openai_responses, :openai_api_key) || System.fetch_env!("OPENAI_API_KEY")
  end
end
