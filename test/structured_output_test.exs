defmodule OpenAI.Responses.StructuredOutputTest do
  use ExUnit.Case
  
  # We'll use this alias in real code, but not in this test file
  # alias OpenAI.Responses
  alias OpenAI.Responses.Schema
  
  test "schema definition" do
    # Simple object schema
    simple_schema = Schema.object(%{
      name: :string,
      age: :integer,
      is_active: :boolean
    })
    
    assert is_map(simple_schema)
    assert simple_schema["type"] == "object"
    assert is_map(simple_schema["properties"])
    assert simple_schema["properties"]["name"]["type"] == "string"
    assert simple_schema["properties"]["age"]["type"] == "integer"
    assert simple_schema["properties"]["is_active"]["type"] == "boolean"
    
    # Array schema
    array_schema = Schema.array(:string)
    
    assert is_map(array_schema)
    assert array_schema["type"] == "array"
    assert array_schema["items"]["type"] == "string"
    
    # Nested schema
    nested_schema = Schema.object(%{
      user: Schema.object(%{
        name: :string,
        email: Schema.string(format: "email")
      }),
      preferences: Schema.object(%{
        theme: :string,
        notifications: :boolean
      })
    })
    
    assert is_map(nested_schema)
    assert nested_schema["type"] == "object"
    assert is_map(nested_schema["properties"]["user"])
    assert nested_schema["properties"]["user"]["properties"]["email"]["format"] == "email"
  end
  
  test "schema with constraints" do
    # String with constraints
    string_schema = Schema.string(min_length: 3, max_length: 20)
    
    assert is_map(string_schema)
    assert string_schema["type"] == "string"
    assert string_schema["minLength"] == 3
    assert string_schema["maxLength"] == 20
    
    # Number with constraints
    number_schema = Schema.number(minimum: 0, maximum: 5)
    
    assert is_map(number_schema)
    assert number_schema["type"] == "number"
    assert number_schema["minimum"] == 0
    assert number_schema["maximum"] == 5
    
    # Array with constraints
    array_schema = Schema.array(:string, min_items: 1, max_items: 5)
    
    assert is_map(array_schema)
    assert array_schema["type"] == "array"
    assert array_schema["minItems"] == 1
    assert array_schema["maxItems"] == 5
  end
  
  test "nullable fields" do
    # Nullable string
    nullable_string = Schema.nullable(:string)
    
    assert is_map(nullable_string)
    assert nullable_string["type"] == ["string", "null"]
    
    # Nullable object
    nullable_object = Schema.nullable(
      Schema.object(%{
        street: :string,
        city: :string
      })
    )
    
    assert is_map(nullable_object)
    assert nullable_object["type"] == ["object", "null"]
    assert is_map(nullable_object["properties"])
  end
end
