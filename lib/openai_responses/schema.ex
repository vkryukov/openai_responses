defmodule OpenAI.Responses.Schema do
  @moduledoc """
  Utilities for defining structured output schemas for OpenAI responses.
  
  This module provides a simple, idiomatic Elixir way to define JSON schemas
  that can be used with the OpenAI Responses API to ensure structured outputs.
  
  ## Simple Usage
  
  For simple types without constraints, you can use atoms directly:
  
      # Using atoms for simple types
      schema = OpenAI.Responses.Schema.object(%{
        name: :string,
        age: :integer,
        is_active: :boolean,
        scores: {:array, :number}
      })
      
  For types with constraints or additional options, use the corresponding functions:
  
      # Using functions for types with constraints
      schema = OpenAI.Responses.Schema.object(%{
        username: OpenAI.Responses.Schema.string(min_length: 3),
        rating: OpenAI.Responses.Schema.number(minimum: 0, maximum: 5)
      })
  """
  
  @doc """
  Creates an object schema definition from a map of field specifications.
  
  ## Parameters
  
    * `fields` - A map where keys are field names and values are type specifications.
      Type specifications can be:
      * Atoms (`:string`, `:number`, `:integer`, `:boolean`) for simple types
      * Tuples like `{:array, type}` for simple arrays
      * Schema maps created by other Schema functions
    * `opts` - Optional parameters
      * `:name` - Name for the root schema
      
  ## Examples
  
      # Simple object schema with atom types
      schema = OpenAI.Responses.Schema.object(%{
        name: :string,
        date: :string,
        participants: {:array, :string}
      }, name: "event")
      
      # Object schema with mixed simple and complex types
      schema = OpenAI.Responses.Schema.object(%{
        name: :string,
        email: OpenAI.Responses.Schema.string(format: "email"),
        age: :integer,
        interests: {:array, :string}
      })
      
      # Use in a response
      {:ok, response} = OpenAI.Responses.create("gpt-4o", "Extract the event...", 
        response_format: %{type: "json_schema", schema: schema}
      )
  """
  def object(fields, opts \\ []) do
    name = Keyword.get(opts, :name)
    additional_properties = Keyword.get(opts, :additional_properties, false)
    
    # Process each field to convert atoms and tuples to proper schema objects
    properties = Map.new(fields, fn {key, value} -> {to_string(key), process_type(value)} end)
    
    schema = %{
      "type" => "object",
      "properties" => properties,
      "required" => Enum.map(Map.keys(fields), &to_string/1),
      "additionalProperties" => additional_properties
    }
    
    if name do
      Map.put(schema, "title", name)
    else
      schema
    end
  end
  
  @doc """
  Creates an array schema definition.
  
  ## Parameters
  
    * `items` - The schema for items in the array. Can be:
      * An atom (`:string`, `:number`, `:integer`, `:boolean`) for simple types
      * A schema map created by other Schema functions
    * `opts` - Optional parameters
      * `:min_items` - Minimum number of items
      * `:max_items` - Maximum number of items
      
  ## Examples
  
      # Array of strings (simple)
      participants_schema = {:array, :string}
      # or
      participants_schema = OpenAI.Responses.Schema.array(:string)
      
      # Array of strings with constraints
      tags_schema = OpenAI.Responses.Schema.array(:string, min_items: 1, max_items: 5)
      
      # Array of objects
      steps_schema = OpenAI.Responses.Schema.array(
        OpenAI.Responses.Schema.object(%{
          explanation: :string,
          output: :string
        })
      )
  """
  def array(items, opts \\ []) do
    min_items = Keyword.get(opts, :min_items)
    max_items = Keyword.get(opts, :max_items)
    
    schema = %{
      "type" => "array",
      "items" => process_type(items)
    }
    
    schema =
      if min_items do
        Map.put(schema, "minItems", min_items)
      else
        schema
      end
      
    schema =
      if max_items do
        Map.put(schema, "maxItems", max_items)
      else
        schema
      end
      
    schema
  end
  
  @doc """
  Creates a string schema definition with optional constraints.
  
  For a simple string without constraints, you can use the atom `:string` directly
  in `object/2` or `array/2` instead of calling this function.
  
  ## Parameters
  
    * `opts` - Optional parameters
      * `:format` - String format (e.g., "date-time", "email")
      * `:pattern` - Regex pattern
      * `:min_length` - Minimum length
      * `:max_length` - Maximum length
      * `:enum` - List of allowed values
      
  ## Examples
  
      # Simple string (in object definition)
      name_field = :string
      
      # Email string
      email_field = OpenAI.Responses.Schema.string(format: "email")
      
      # String with length constraints
      username_field = OpenAI.Responses.Schema.string(
        min_length: 3,
        max_length: 20
      )
      
      # String with allowed values (enum)
      status_field = OpenAI.Responses.Schema.string(
        enum: ["pending", "active", "completed"]
      )
  """
  def string(opts \\ []) do
    schema = %{"type" => "string"}
    
    schema =
      if format = Keyword.get(opts, :format) do
        Map.put(schema, "format", format)
      else
        schema
      end
      
    schema =
      if pattern = Keyword.get(opts, :pattern) do
        Map.put(schema, "pattern", pattern)
      else
        schema
      end
      
    schema =
      if min_length = Keyword.get(opts, :min_length) do
        Map.put(schema, "minLength", min_length)
      else
        schema
      end
      
    schema =
      if max_length = Keyword.get(opts, :max_length) do
        Map.put(schema, "maxLength", max_length)
      else
        schema
      end
      
    schema =
      if enum = Keyword.get(opts, :enum) do
        Map.put(schema, "enum", enum)
      else
        schema
      end
      
    schema
  end
  
  @doc """
  Creates a number schema definition with optional constraints.
  
  For a simple number without constraints, you can use the atom `:number` directly
  in `object/2` or `array/2` instead of calling this function.
  
  ## Parameters
  
    * `opts` - Optional parameters
      * `:minimum` - Minimum value
      * `:maximum` - Maximum value
      * `:exclusive_minimum` - Whether minimum is exclusive
      * `:exclusive_maximum` - Whether maximum is exclusive
      * `:multiple_of` - Number must be multiple of this value
      
  ## Examples
  
      # Simple number (in object definition)
      price_field = :number
      
      # Number with range
      rating_field = OpenAI.Responses.Schema.number(
        minimum: 0,
        maximum: 5
      )
      
      # Positive number
      quantity_field = OpenAI.Responses.Schema.number(
        minimum: 0,
        exclusive_minimum: true
      )
      
      # Multiple of 0.5
      half_step_field = OpenAI.Responses.Schema.number(
        multiple_of: 0.5
      )
  """
  def number(opts \\ []) do
    schema = %{"type" => "number"}
    
    schema =
      if minimum = Keyword.get(opts, :minimum) do
        Map.put(schema, "minimum", minimum)
      else
        schema
      end
      
    schema =
      if maximum = Keyword.get(opts, :maximum) do
        Map.put(schema, "maximum", maximum)
      else
        schema
      end
      
    schema =
      if exclusive_minimum = Keyword.get(opts, :exclusive_minimum) do
        Map.put(schema, "exclusiveMinimum", exclusive_minimum)
      else
        schema
      end
      
    schema =
      if exclusive_maximum = Keyword.get(opts, :exclusive_maximum) do
        Map.put(schema, "exclusiveMaximum", exclusive_maximum)
      else
        schema
      end
      
    schema =
      if multiple_of = Keyword.get(opts, :multiple_of) do
        Map.put(schema, "multipleOf", multiple_of)
      else
        schema
      end
      
    schema
  end
  
  @doc """
  Creates an integer schema definition with optional constraints.
  
  For a simple integer without constraints, you can use the atom `:integer` directly
  in `object/2` or `array/2` instead of calling this function.
  
  ## Parameters
  
    * `opts` - Optional parameters
      * `:minimum` - Minimum value
      * `:maximum` - Maximum value
      * `:exclusive_minimum` - Whether minimum is exclusive
      * `:exclusive_maximum` - Whether maximum is exclusive
      * `:multiple_of` - Integer must be multiple of this value
      
  ## Examples
  
      # Simple integer (in object definition)
      count_field = :integer
      
      # Integer with range
      age_field = OpenAI.Responses.Schema.integer(
        minimum: 0,
        maximum: 120
      )
      
      # Positive integer
      quantity_field = OpenAI.Responses.Schema.integer(
        minimum: 1
      )
  """
  def integer(opts \\ []) do
    schema = %{"type" => "integer"}
    
    schema =
      if minimum = Keyword.get(opts, :minimum) do
        Map.put(schema, "minimum", minimum)
      else
        schema
      end
      
    schema =
      if maximum = Keyword.get(opts, :maximum) do
        Map.put(schema, "maximum", maximum)
      else
        schema
      end
      
    schema =
      if exclusive_minimum = Keyword.get(opts, :exclusive_minimum) do
        Map.put(schema, "exclusiveMinimum", exclusive_minimum)
      else
        schema
      end
      
    schema =
      if exclusive_maximum = Keyword.get(opts, :exclusive_maximum) do
        Map.put(schema, "exclusiveMaximum", exclusive_maximum)
      else
        schema
      end
      
    schema =
      if multiple_of = Keyword.get(opts, :multiple_of) do
        Map.put(schema, "multipleOf", multiple_of)
      else
        schema
      end
      
    schema
  end
  
  @doc """
  Creates a boolean schema definition.
  
  For a simple boolean, you can use the atom `:boolean` directly
  in `object/2` or `array/2` instead of calling this function.
  
  ## Examples
  
      # Boolean field (in object definition)
      is_active_field = :boolean
      
      # Or using the function
      is_active_field = OpenAI.Responses.Schema.boolean()
  """
  def boolean do
    %{"type" => "boolean"}
  end
  
  @doc """
  Creates a nullable schema definition.
  
  ## Parameters
  
    * `schema` - The base schema or atom type
    
  ## Examples
  
      # Nullable string
      middle_name_field = OpenAI.Responses.Schema.nullable(:string)
      
      # Nullable object
      address_field = OpenAI.Responses.Schema.nullable(
        OpenAI.Responses.Schema.object(%{
          street: :string,
          city: :string,
          zip: :string
        })
      )
  """
  def nullable(schema) do
    processed_schema = process_type(schema)
    
    # If the schema has a type field, make it nullable by adding "null" to the type
    if Map.has_key?(processed_schema, "type") do
      type_value = processed_schema["type"]
      new_type = if is_binary(type_value), do: [type_value, "null"], else: type_value
      Map.put(processed_schema, "type", new_type)
    else
      # Fallback to anyOf for complex schemas without a direct type
      %{
        "anyOf" => [
          processed_schema,
          %{"type" => "null"}
        ]
      }
    end
  end
  
  # Private helpers
  
  # Process different type specifications into proper schema objects
  defp process_type(:string), do: %{"type" => "string"}
  defp process_type(:number), do: %{"type" => "number"}
  defp process_type(:integer), do: %{"type" => "integer"}
  defp process_type(:boolean), do: %{"type" => "boolean"}
  defp process_type({:array, items}), do: array(items)
  defp process_type(schema) when is_map(schema), do: schema
  defp process_type(other), do: raise "Unsupported type specification: #{inspect(other)}"
end
