defmodule OpenAI.Responses.Schema do
  @moduledoc """
  Helper module for defining structured output schemas and function calling tools.

  Converts simple Elixir syntax into JSON Schema format for structured outputs and function parameters.

  ## Examples

  ### Structured Output Schema

      iex> Responses.Schema.build_output(%{
      ...>   name: {:string, description: "The name of the user"},
      ...>   username: {:string, description: "The username of the user. Must start with @", pattern: "^@[a-zA-Z0-9_]+$"},
      ...>   email: {:string, description: "The email of the user", format: "email"}
      ...> })
      %{
        "name" => "data",
        "type" => "json_schema",
        "strict" => true,
        "schema" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{
              "type" => "string",
              "description" => "The name of the user"
            },
            "username" => %{
              "type" => "string",
              "description" => "The username of the user. Must start with @",
              "pattern" => "^@[a-zA-Z0-9_]+$"
            },
            "email" => %{
              "type" => "string",
              "description" => "The email of the user",
              "format" => "email"
            }
          },
          "additionalProperties" => false,
          "required" => ["name", "username", "email"]
        }
      }

  ### Function Calling Tool

      iex> Responses.Schema.build_function("get_weather", "Get current temperature for a given location.", %{
      ...>   location: {:string, description: "City and country e.g. Bogotá, Colombia"}
      ...> })
      %{
        "name" => "get_weather",
        "type" => "function",
        "strict" => true,
        "description" => "Get current temperature for a given location.",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "location" => %{
              "type" => "string",
              "description" => "City and country e.g. Bogotá, Colombia"
            }
          },
          "additionalProperties" => false,
          "required" => ["location"]
        }
      }
  """

  @doc """
  Builds a structured output schema from a simple Elixir map or keyword list format.

  The input should be a map or keyword list where:
  - Keys are field names (atoms)
  - Values are either:
    - A single atom like `:string`, `:number`, `:boolean`, etc.
    - A tuple like `{:string, description: "...", pattern: "..."}`
    - For arrays: `{:array, :string}` or `{:array, %{field: :type}}`

  When using keyword lists, the order of fields is preserved in the required array.
  When using maps, fields are sorted alphabetically in the required array.
  """
  def build_output(fields) do
    %{
      "name" => "data",
      "type" => "json_schema",
      "strict" => true,
      "schema" => build_schema(fields)
    }
  end

  @doc """
  Builds a function calling tool schema.

  ## Parameters
    - `name` - The function name
    - `description` - A description of what the function does
    - `parameters` - A map or keyword list of parameter definitions (same format as `build_output/1`)

  ## Example

      iex> build_function("get_weather", "Get weather for a location", %{
      ...>   location: {:string, description: "City name"},
      ...>   units: {:string, enum: ["celsius", "fahrenheit"], description: "Temperature units"}
      ...> })
  """
  def build_function(name, description, parameters) do
    %{
      "name" => name,
      "type" => "function",
      "strict" => true,
      "description" => description,
      "parameters" => build_schema(parameters)
    }
  end

  defp build_schema(fields) when is_map(fields) or is_list(fields) do
    build_property(fields)
  end

  defp build_property(spec) do
    spec
    |> normalize_spec()
    |> build_from_normalized()
  end

  # Normalize various input formats to a standard map format
  defp normalize_spec(spec) do
    case spec do
      # Simple types
      type when is_atom(type) or is_binary(type) ->
        %{"type" => to_string(type)}

      # Arrays - both {:array, ...} and {"array", ...}
      {array_type, item_spec} when array_type in [:array, "array"] ->
        %{"type" => "array", "items" => normalize_spec(item_spec)}

      # Arrays in list format - [:array, item_spec]
      [array_type, item_spec] when array_type in [:array, "array"] ->
        %{"type" => "array", "items" => normalize_spec(item_spec)}

      # Lists with exactly 2 elements - treat as [type, options]
      [type, opts] when (is_atom(type) or is_binary(type)) and (is_list(opts) or is_map(opts)) ->
        if type in [:object, "object"] and is_map(opts) and Map.has_key?(opts, :properties) do
          # Special case for [:object, %{properties: ...}]
          properties = Map.get(opts, :properties)
          normalize_object_spec(Enum.to_list(properties))
        else
          normalize_type_with_options(type, opts)
        end

      # Tuples with type and options
      {type, opts} when (is_atom(type) or is_binary(type)) and is_list(opts) ->
        if type in [:object, "object"] and Keyword.has_key?(opts, :properties) do
          # Special case for {:object, properties: ...}
          properties = Keyword.get(opts, :properties)
          normalize_object_spec(Enum.to_list(properties))
        else
          normalize_type_with_options(type, opts)
        end

      # Object specifications - keyword lists or lists of tuples
      list when is_list(list) and list != [] and is_tuple(hd(list)) ->
        normalize_object_spec(list)
        
      # Empty list
      [] ->
        normalize_object_spec([])

      # Maps are object specifications
      map when is_map(map) ->
        # Convert to sorted keyword list for consistent ordering
        map
        |> Enum.sort_by(fn {key, _} -> to_string(key) end)
        |> normalize_object_spec()

      # Fallback for edge cases
      _ ->
        raise ArgumentError, "Unsupported schema specification: #{inspect(spec)}"
    end
  end

  defp normalize_type_with_options(type, opts) do
    base = %{"type" => to_string(type)}
    
    # Convert options to map if they're a keyword list
    opts_map = if is_list(opts), do: Map.new(opts), else: opts
    
    # Merge options into base, converting keys to strings
    Enum.reduce(opts_map, base, fn {key, value}, acc ->
      Map.put(acc, to_string(key), value)
    end)
  end

  defp normalize_object_spec(spec) do
    properties =
      spec
      |> Enum.map(fn {name, child_spec} -> 
        {to_string(name), normalize_spec(child_spec)}
      end)
      |> Map.new()

    required =
      spec
      |> Enum.map(fn {key, _} -> to_string(key) end)

    %{
      "type" => "object",
      "properties" => properties,
      "required" => required
    }
  end

  # Build the final property from normalized format
  defp build_from_normalized(%{"type" => "array", "items" => items}) do
    %{
      "type" => "array",
      "items" => build_from_normalized(items)
    }
  end

  defp build_from_normalized(%{"type" => "object", "properties" => properties, "required" => required}) do
    built_properties =
      properties
      |> Enum.map(fn {name, prop} -> {name, build_from_normalized(prop)} end)
      |> Map.new()

    %{
      "type" => "object",
      "properties" => built_properties,
      "additionalProperties" => false,
      "required" => required
    }
  end

  defp build_from_normalized(spec) when is_map(spec) do
    # Already in final format
    spec
  end
end
