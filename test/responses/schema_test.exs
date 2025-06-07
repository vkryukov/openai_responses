defmodule OpenAI.Responses.SchemaTest do
  use ExUnit.Case
  alias OpenAI.Responses.Schema

  describe "build_output/1 with maps" do
    test "converts simple types" do
      result =
        Schema.build_output(%{
          name: :string,
          age: :number,
          active: :boolean
        })

      assert result == %{
               "name" => "data",
               "type" => "json_schema",
               "strict" => true,
               "schema" => %{
                 "type" => "object",
                 "properties" => %{
                   "name" => %{"type" => "string"},
                   "age" => %{"type" => "number"},
                   "active" => %{"type" => "boolean"}
                 },
                 "additionalProperties" => false,
                 "required" => ["active", "age", "name"]
               }
             }
    end

    test "converts types with options" do
      result =
        Schema.build_output(%{
          name: {:string, description: "The name of the user"},
          username:
            {:string,
             description: "The username of the user. Must start with @",
             pattern: "^@[a-zA-Z0-9_]+$"},
          email: {:string, description: "The email of the user", format: "email"}
        })

      assert result == %{
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
                 "required" => ["email", "name", "username"]
               }
             }
    end

    test "converts array types" do
      result =
        Schema.build_output(%{
          tags: {:array, :string},
          scores: {:array, :number}
        })

      assert result["schema"]["properties"]["tags"] == %{
               "type" => "array",
               "items" => %{"type" => "string"}
             }

      assert result["schema"]["properties"]["scores"] == %{
               "type" => "array",
               "items" => %{"type" => "number"}
             }
    end

    test "converts array of objects" do
      result =
        Schema.build_output(%{
          users:
            {:array,
             %{
               name: :string,
               email: {:string, format: "email"}
             }}
        })

      assert result["schema"]["properties"]["users"] == %{
               "type" => "array",
               "items" => %{
                 "type" => "object",
                 "properties" => %{
                   "name" => %{"type" => "string"},
                   "email" => %{"type" => "string", "format" => "email"}
                 },
                 "additionalProperties" => false,
                 "required" => ["email", "name"]
               }
             }
    end

    test "converts nested objects" do
      result =
        Schema.build_output(%{
          user: %{
            name: :string,
            contact: %{
              email: {:string, format: "email"},
              phone: :string
            }
          }
        })

      assert result["schema"]["properties"]["user"] == %{
               "type" => "object",
               "properties" => %{
                 "name" => %{"type" => "string"},
                 "contact" => %{
                   "type" => "object",
                   "properties" => %{
                     "email" => %{"type" => "string", "format" => "email"},
                     "phone" => %{"type" => "string"}
                   },
                   "additionalProperties" => false,
                   "required" => ["email", "phone"]
                 }
               },
               "additionalProperties" => false,
               "required" => ["contact", "name"]
             }
    end
  end

  describe "build_output/1 with keyword lists" do
    test "converts simple types with preserved order" do
      result =
        Schema.build_output(
          name: :string,
          age: :number,
          active: :boolean
        )

      assert result == %{
               "name" => "data",
               "type" => "json_schema",
               "strict" => true,
               "schema" => %{
                 "type" => "object",
                 "properties" => %{
                   "name" => %{"type" => "string"},
                   "age" => %{"type" => "number"},
                   "active" => %{"type" => "boolean"}
                 },
                 "additionalProperties" => false,
                 "required" => ["name", "age", "active"]
               }
             }
    end

    test "converts types with options and preserves order" do
      result =
        Schema.build_output(
          username:
            {"string",
             description: "The username of the user. Must start with @",
             pattern: "^@[a-zA-Z0-9_]+$"},
          name: {:string, description: "The name of the user"},
          email: {:string, description: "The email of the user", format: "email"}
        )

      # Required should preserve the keyword list order
      assert result["schema"]["required"] == ["username", "name", "email"]
    end

    test "preserves order vs maps sort alphabetically" do
      keyword_result = Schema.build_output(z: :string, a: :string, m: :string)
      map_result = Schema.build_output(%{z: :string, a: :string, m: :string})

      assert keyword_result["schema"]["required"] == ["z", "a", "m"]
      assert map_result["schema"]["required"] == ["a", "m", "z"]
    end
  end

  describe "build_function/3" do
    test "creates function schema with simple parameters" do
      result =
        Schema.build_function("get_weather", "Get current temperature for a given location.", %{
          location: {:string, description: "City and country e.g. Bogotá, Colombia"}
        })

      assert result == %{
               "type" => "function",
               "name" => "get_weather",
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
    end

    test "creates function schema with multiple parameters" do
      result =
        Schema.build_function("send_email", "Send an email to a recipient", %{
          to: {:string, description: "Recipient email address", format: "email"},
          subject: {:string, description: "Email subject"},
          body: {:string, description: "Email body content"},
          attachments: {:array, :string}
        })

      assert result["type"] == "function"
      assert result["name"] == "send_email"
      assert result["description"] == "Send an email to a recipient"
      assert result["parameters"]["properties"]["to"]["format"] == "email"
      assert result["parameters"]["properties"]["attachments"]["type"] == "array"
      assert result["parameters"]["required"] == ["attachments", "body", "subject", "to"]
    end

    test "creates function schema with nested parameters" do
      result =
        Schema.build_function("create_user", "Create a new user account", %{
          name: :string,
          profile: %{
            bio: {:string, description: "User biography"},
            avatar_url: {:string, format: "uri"}
          }
        })

      assert result["parameters"]["properties"]["profile"]["type"] == "object"

      assert result["parameters"]["properties"]["profile"]["properties"]["bio"]["description"] ==
               "User biography"
    end
  end
end
