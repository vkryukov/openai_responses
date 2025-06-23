defmodule OpenAI.Responses.InputFormatTest do
  use ExUnit.Case, async: true
  
  alias OpenAI.Responses
  alias OpenAI.Responses.Internal
  
  describe "Internal.prepare_payload/1" do
    test "handles keyword lists with atom keys" do
      payload = Internal.prepare_payload([
        input: "test",
        schema: %{name: :string}
      ])
      
      assert payload["input"] == "test"
      assert payload["text"]["format"]["schema"]["properties"]["name"]["type"] == "string"
    end
    
    test "handles maps with atom keys" do
      payload = Internal.prepare_payload(%{
        input: "test",
        schema: %{name: :string}
      })
      
      assert payload["input"] == "test"
      assert payload["text"]["format"]["schema"]["properties"]["name"]["type"] == "string"
    end
    
    test "handles maps with string keys" do
      options = %{
        "input" => "test",
        "schema" => %{name: :string}
      }
      
      payload = Internal.prepare_payload(options)
      
      assert payload["input"] == "test"
      assert payload["text"]["format"]["schema"]["properties"]["name"]["type"] == "string"
    end
    
    test "handles mixed string and atom keys in maps" do
      # Maps can't have mixed key types in literals, so we build it dynamically
      options = %{"input" => "test", "schema" => %{name: :string}}
      options = Map.put(options, :model, "gpt-4")
      
      payload = Internal.prepare_payload(options)
      
      assert payload["input"] == "test"
      assert payload["model"] == "gpt-4"
      assert payload["text"]["format"]["schema"]["properties"]["name"]["type"] == "string"
    end
    
    test "handles lists with string key tuples" do
      payload = Internal.prepare_payload([
        {"input", "test"},
        {"schema", %{name: :string}}
      ])
      
      assert payload["input"] == "test"
      assert payload["text"]["format"]["schema"]["properties"]["name"]["type"] == "string"
    end
    
    test "handles complex nested schemas with tuples" do
      payload = Internal.prepare_payload(%{
        "input" => "test",
        "schema" => %{
          presidents: {:array, %{
            name: :string,
            birth_year: :integer,
            little_known_facts: {:array, {:string, max_items: 2}}
          }}
        }
      })
      
      assert payload["input"] == "test"
      
      schema = payload["text"]["format"]["schema"]
      presidents_schema = schema["properties"]["presidents"]
      assert presidents_schema["type"] == "array"
      
      item_schema = presidents_schema["items"]
      assert item_schema["properties"]["name"]["type"] == "string"
      assert item_schema["properties"]["birth_year"]["type"] == "integer"
      
      facts_schema = item_schema["properties"]["little_known_facts"]
      assert facts_schema["type"] == "array"
      assert facts_schema["items"]["type"] == "string"
      assert facts_schema["items"]["max_items"] == 2
    end
    
    test "handles array syntax with brackets" do
      payload = Internal.prepare_payload(%{
        "input" => "test",
        "schema" => %{
          presidents: [:array, %{
            name: :string,
            birth_year: :integer,
            little_known_facts: [:array, [:string, [max_items: 2]]]
          }]
        }
      })
      
      assert payload["input"] == "test"
      
      schema = payload["text"]["format"]["schema"]
      presidents_schema = schema["properties"]["presidents"]
      assert presidents_schema["type"] == "array"
      
      facts_schema = presidents_schema["items"]["properties"]["little_known_facts"]
      assert facts_schema["type"] == "array"
      assert facts_schema["items"]["type"] == "string"
      assert facts_schema["items"]["max_items"] == 2
    end
    
    test "preserves non-schema options" do
      payload = Internal.prepare_payload(%{
        "input" => "test",
        "model" => "gpt-4",
        "temperature" => 0.7,
        "max_completion_tokens" => 1000
      })
      
      assert payload["input"] == "test"
      assert payload["model"] == "gpt-4"
      assert payload["temperature"] == 0.7
      assert payload["max_completion_tokens"] == 1000
    end
    
    test "adds default model when not specified" do
      payload = Internal.prepare_payload(%{"input" => "test"})
      assert payload["model"] == "gpt-4.1-mini"
    end
    
    test "uses provided model over default" do
      payload = Internal.prepare_payload(%{"input" => "test", "model" => "gpt-4"})
      assert payload["model"] == "gpt-4"
    end
  end
  
  describe "API integration with various input formats" do
    @describetag :api
    test "create/1 with map and string keys including schema" do
      {:ok, response} = Responses.create(%{
        "input" => "List one fact about George Washington",
        "schema" => %{
          fact: :string
        }
      })
      
      assert response.parsed["fact"]
      assert is_binary(response.parsed["fact"])
    end
    
    test "create/1 with complex nested schema using tuples" do
      {:ok, response} = Responses.create(%{
        "input" => "List facts about the first U.S. President",
        "schema" => %{
          president: %{
            name: :string,
            facts: {:array, :string}
          }
        }
      })
      
      assert response.parsed["president"]["name"]
      assert is_list(response.parsed["president"]["facts"])
    end
  end
end