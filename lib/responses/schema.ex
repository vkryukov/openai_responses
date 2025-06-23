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
    cond do
      # Simple types
      simple_type?(spec) ->
        normalize_simple_type(spec)

      # Arrays
      array_spec?(spec) ->
        normalize_array_spec(spec)

      # Union types (anyOf)
      anyof_spec?(spec) ->
        normalize_anyof_spec(spec)

      # Type with options
      type_with_options?(spec) ->
        normalize_type_with_options_spec(spec)

      # Lists (keyword lists or empty)
      is_list(spec) ->
        normalize_list_spec(spec)

      # Maps are object specifications
      is_map(spec) ->
        normalize_map_spec(spec)

      # Fallback
      true ->
        raise ArgumentError, "Unsupported schema specification: #{inspect(spec)}"
    end
  end

  # Type checking helpers
  defp simple_type?(type) when is_atom(type) or is_binary(type), do: true
  defp simple_type?(_), do: false

  defp array_spec?({type, _}) when type in [:array, "array"], do: true
  defp array_spec?([type, _]) when type in [:array, "array"], do: true
  defp array_spec?(_), do: false

  defp anyof_spec?({type, specs}) when type in [:anyOf, "anyOf"] and is_list(specs), do: true
  defp anyof_spec?([type, specs]) when type in [:anyOf, "anyOf"] and is_list(specs), do: true
  defp anyof_spec?(_), do: false

  defp type_with_options?([type, opts]) when (is_atom(type) or is_binary(type)) and (is_list(opts) or is_map(opts)), do: true
  defp type_with_options?({type, opts}) when (is_atom(type) or is_binary(type)) and is_list(opts), do: true
  defp type_with_options?(_), do: false

  # Normalization helpers
  defp normalize_simple_type(type) do
    %{"type" => to_string(type)}
  end

  defp normalize_array_spec({_array_type, item_spec}) do
    %{"type" => "array", "items" => normalize_spec(item_spec)}
  end

  defp normalize_array_spec([_array_type, item_spec]) do
    %{"type" => "array", "items" => normalize_spec(item_spec)}
  end

  defp normalize_anyof_spec({_anyof_type, specs}) do
    %{"anyOf" => Enum.map(specs, &normalize_spec/1)}
  end

  defp normalize_anyof_spec([_anyof_type, specs]) do
    %{"anyOf" => Enum.map(specs, &normalize_spec/1)}
  end

  defp normalize_type_with_options_spec([type, opts]) do
    opts = normalize_nested_options(opts)
    handle_type_with_options(type, opts, &Map.has_key?/2, &Map.get/2)
  end

  defp normalize_type_with_options_spec({type, opts}) do
    handle_type_with_options(type, opts, &Keyword.has_key?/2, &Keyword.get/2)
  end

  defp handle_type_with_options(type, opts, has_key_fn, get_fn) do
    if type in [:object, "object"] and has_key_fn.(opts, :properties) do
      properties = get_fn.(opts, :properties)
      normalize_object_spec(Enum.to_list(properties))
    else
      normalize_type_with_options(type, opts)
    end
  end

  defp normalize_list_spec([]) do
    normalize_object_spec([])
  end

  defp normalize_list_spec(list) when is_tuple(hd(list)) do
    normalize_object_spec(list)
  end

  defp normalize_list_spec(spec) do
    raise ArgumentError, "Unsupported schema specification: #{inspect(spec)}"
  end

  defp normalize_map_spec(map) do
    map
    |> Enum.sort_by(fn {key, _} -> to_string(key) end)
    |> normalize_object_spec()
  end

  # Handle nested list options like [:max_items, 2] -> [max_items: 2]
  defp normalize_nested_options(opts) when is_list(opts) do
    case opts do
      # Single nested list like [:max_items, 2]
      [[key, value]] when is_atom(key) or is_binary(key) ->
        [{key, value}]
      
      # Direct list like [:max_items, 2] that's not a keyword list
      [key, value] when (is_atom(key) or is_binary(key)) and not is_tuple(value) ->
        [{key, value}]
      
      # Already a proper keyword list or other format
      _ ->
        opts
    end
  end
  
  defp normalize_nested_options(opts), do: opts

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

  defp build_from_normalized(%{"anyOf" => specs}) do
    %{
      "anyOf" => Enum.map(specs, &build_from_normalized/1)
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
