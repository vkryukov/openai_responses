defmodule OpenAI.Responses.ArraySchemaTest do
  use ExUnit.Case, async: true

  alias OpenAI.Responses.Schema
  alias OpenAI.Responses.Response

  describe "Schema.build_output/1 with array at root" do
    test "wraps array schema in an object" do
      array_schema =
        {:array,
         %{
           name: :string,
           birth_year: :integer,
           little_known_facts: {:array, {:string, max_items: 2}}
         }}

      result = Schema.build_output(array_schema)

      assert result["type"] == "json_schema"
      assert result["strict"] == true

      schema = result["schema"]
      assert schema["type"] == "object"
      assert Map.keys(schema["properties"]) == ["items"]
      assert schema["required"] == ["items"]
      assert schema["additionalProperties"] == false

      items_schema = schema["properties"]["items"]
      assert items_schema["type"] == "array"
      assert items_schema["items"]["type"] == "object"

      assert Map.keys(items_schema["items"]["properties"]) |> Enum.sort() == [
               "birth_year",
               "little_known_facts",
               "name"
             ]
    end

    test "does not wrap regular object schema" do
      object_schema = %{
        name: :string,
        age: :integer
      }

      result = Schema.build_output(object_schema)
      schema = result["schema"]

      assert schema["type"] == "object"
      assert Map.has_key?(schema["properties"], "name")
      assert Map.has_key?(schema["properties"], "age")
      assert not Map.has_key?(schema["properties"], "items")
    end

    test "handles nested arrays correctly" do
      nested_array_schema = {:array, {:array, :string}}

      result = Schema.build_output(nested_array_schema)
      schema = result["schema"]

      assert schema["type"] == "object"
      assert Map.keys(schema["properties"]) == ["items"]

      items_schema = schema["properties"]["items"]
      assert items_schema["type"] == "array"
      assert items_schema["items"]["type"] == "array"
      assert items_schema["items"]["items"]["type"] == "string"
    end
  end

  describe "Response.extract_json/1 with wrapped arrays" do
    test "unwraps array that was wrapped for OpenAI compatibility" do
      mock_response = %Response{
        text:
          ~s({"items": [{"name": "George Washington", "birth_year": 1732, "little_known_facts": ["Had dental issues", "Was a surveyor"]}, {"name": "Abraham Lincoln", "birth_year": 1809, "little_known_facts": ["Self-taught lawyer", "Loved cats"]}]}),
        body: %{
          "text" => %{
            "format" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{
                  "items" => %{
                    "type" => "array",
                    "items" => %{"type" => "object"}
                  }
                },
                "required" => ["items"],
                "additionalProperties" => false
              }
            }
          }
        }
      }

      result = Response.extract_json(mock_response)

      assert is_list(result.parsed)
      assert length(result.parsed) == 2
      assert Enum.at(result.parsed, 0)["name"] == "George Washington"
      assert Enum.at(result.parsed, 0)["birth_year"] == 1732
      assert Enum.at(result.parsed, 1)["name"] == "Abraham Lincoln"
      assert Enum.at(result.parsed, 1)["birth_year"] == 1809
    end

    test "does not unwrap regular object responses" do
      mock_response = %Response{
        text: ~s({"name": "Test User", "age": 25}),
        body: %{
          "text" => %{
            "format" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{
                  "name" => %{"type" => "string"},
                  "age" => %{"type" => "integer"}
                }
              }
            }
          }
        }
      }

      result = Response.extract_json(mock_response)

      assert is_map(result.parsed)
      assert result.parsed["name"] == "Test User"
      assert result.parsed["age"] == 25
    end

    test "does not unwrap objects that happen to have an 'items' property" do
      mock_response = %Response{
        text: ~s({"items": [1, 2, 3], "total": 3, "page": 1}),
        body: %{
          "text" => %{
            "format" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{
                  "items" => %{"type" => "array", "items" => %{"type" => "integer"}},
                  "total" => %{"type" => "integer"},
                  "page" => %{"type" => "integer"}
                },
                "required" => ["items", "total", "page"]
              }
            }
          }
        }
      }

      result = Response.extract_json(mock_response)

      assert is_map(result.parsed)
      assert result.parsed["items"] == [1, 2, 3]
      assert result.parsed["total"] == 3
      assert result.parsed["page"] == 1
    end

    test "handles parse errors gracefully" do
      mock_response = %Response{
        text: ~s(invalid json),
        body: %{
          "text" => %{
            "format" => %{
              "schema" => %{"type" => "object"}
            }
          }
        }
      }

      result = Response.extract_json(mock_response)

      assert result.parsed == nil
      assert is_map(result.parse_error)
      assert Map.has_key?(result.parse_error, :json)
    end
  end
end
