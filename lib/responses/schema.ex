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

  defp build_property(type) when is_binary(type) do
    %{"type" => type}
  end

  defp build_property(type) when is_atom(type) do
    %{"type" => to_string(type)}
  end

  defp build_property({:array, item_type}) do
    %{
      "type" => "array",
      "items" => build_property(item_type)
    }
  end

  defp build_property({type, opts}) when (is_atom(type) or is_binary(type)) and is_list(opts) do
    base = %{"type" => to_string(type)}

    Enum.reduce(opts, base, fn {key, value}, acc ->
      Map.put(acc, to_string(key), value)
    end)
  end

  defp build_property(object_spec) when is_list(object_spec) do
    properties =
      object_spec
      |> Enum.map(fn {name, spec} -> {to_string(name), build_property(spec)} end)
      |> Map.new()

    required =
      object_spec
      |> Keyword.keys()
      |> Enum.map(&to_string/1)

    %{
      "type" => "object",
      "properties" => properties,
      "additionalProperties" => false,
      "required" => required
    }
  end

  defp build_property(object_spec) when is_map(object_spec) do
    # Convert map to keyword list and delegate to preserve consistent behavior
    # but sort the keys since maps don't have guaranteed order
    keyword_list =
      object_spec
      |> Enum.sort_by(fn {key, _} -> to_string(key) end)

    build_property(keyword_list)
  end
end
