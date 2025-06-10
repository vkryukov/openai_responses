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

    test "converts array types with string tuple syntax" do
      result =
        Schema.build_output(%{
          tags: {"array", :string},
          scores: {"array", :number}
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

    test "converts array of objects with string tuple syntax" do
      result =
        Schema.build_output(%{
          users:
            {"array",
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

  describe "build_output/1 with string key pairs" do
    test "converts simple types with string keys instead of atoms" do
      # This simulates data that might come from a database where keys are strings
      result =
        Schema.build_output([
          {"name", :string},
          {"age", :number},
          {"active", :boolean}
        ])

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

    test "converts nested objects with string keys" do
      result =
        Schema.build_output([
          {"user",
           [
             {"name", :string},
             {"contact",
              [
                {"email", {:string, format: "email"}},
                {"phone", :string}
              ]}
           ]}
        ])

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
               "required" => ["name", "contact"]
             }
    end

    test "converts array types with string keys" do
      result =
        Schema.build_output([
          {"tags", {:array, :string}},
          {"scores", {"array", :number}}
        ])

      assert result["schema"]["properties"]["tags"] == %{
               "type" => "array",
               "items" => %{"type" => "string"}
             }

      assert result["schema"]["properties"]["scores"] == %{
               "type" => "array",
               "items" => %{"type" => "number"}
             }
    end
  end

  describe "build_output/1 with list format" do
    test "converts types with list format [type, map]" do
      result =
        Schema.build_output(%{
          name: [:string, %{description: "Full name"}],
          year: [:integer, %{description: "Year of birth"}]
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
                     "description" => "Full name"
                   },
                   "year" => %{
                     "type" => "integer",
                     "description" => "Year of birth"
                   }
                 },
                 "additionalProperties" => false,
                 "required" => ["name", "year"]
               }
             }
    end

    test "converts types with list format including pattern and format" do
      result =
        Schema.build_output(%{
          username: [:string, %{description: "Username", pattern: "^@[a-zA-Z0-9_]+$"}],
          email: [:string, %{description: "Email address", format: "email"}]
        })

      assert result["schema"]["properties"]["username"] == %{
               "type" => "string",
               "description" => "Username",
               "pattern" => "^@[a-zA-Z0-9_]+$"
             }

      assert result["schema"]["properties"]["email"] == %{
               "type" => "string",
               "description" => "Email address",
               "format" => "email"
             }
    end

    test "mixes list format with tuple format" do
      result =
        Schema.build_output(%{
          name: [:string, %{description: "Name using list format"}],
          age: {:number, description: "Age using tuple format"},
          active: :boolean
        })

      assert result["schema"]["properties"]["name"] == %{
               "type" => "string",
               "description" => "Name using list format"
             }

      assert result["schema"]["properties"]["age"] == %{
               "type" => "number",
               "description" => "Age using tuple format"
             }

      assert result["schema"]["properties"]["active"] == %{
               "type" => "boolean"
             }
    end

    test "supports list format with keyword list options" do
      result =
        Schema.build_output(%{
          name: [:string, [description: "Full name", minLength: 2]],
          email: [:string, [format: "email", description: "Email address"]]
        })

      assert result["schema"]["properties"]["name"] == %{
               "type" => "string",
               "description" => "Full name",
               "minLength" => 2
             }

      assert result["schema"]["properties"]["email"] == %{
               "type" => "string",
               "format" => "email",
               "description" => "Email address"
             }
    end

    test "supports deeply nested mixed formats" do
      result =
        Schema.build_output(%{
          user: [
            :object,
            %{
              properties: %{
                name: [:string, [description: "User name"]],
                profile: {:object, properties: %{bio: :string, age: [:integer, %{minimum: 0}]}}
              }
            }
          ]
        })

      assert get_in(result, ["schema", "properties", "user", "properties", "name"]) == %{
               "type" => "string",
               "description" => "User name"
             }

      assert get_in(result, ["schema", "properties", "user", "properties", "profile", "properties", "age"]) == %{
               "type" => "integer",
               "minimum" => 0
             }
    end
  end

  describe "build_function/3" do
    test "creates function schema with string key parameters" do
      # Test that build_function also works with string keys
      result =
        Schema.build_function("get_user", "Get user information", [
          {"user_id", {:string, description: "The ID of the user"}},
          {"include_profile", :boolean}
        ])

      assert result == %{
               "type" => "function",
               "name" => "get_user",
               "strict" => true,
               "description" => "Get user information",
               "parameters" => %{
                 "type" => "object",
                 "properties" => %{
                   "user_id" => %{
                     "type" => "string",
                     "description" => "The ID of the user"
                   },
                   "include_profile" => %{"type" => "boolean"}
                 },
                 "additionalProperties" => false,
                 "required" => ["user_id", "include_profile"]
               }
             }
    end

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

    test "creates function schema with string tuple array syntax" do
      result =
        Schema.build_function("process_data", "Process data arrays", %{
          items: {"array", :string},
          metadata: {"array", %{key: :string, value: :string}}
        })

      assert result["parameters"]["properties"]["items"] == %{
               "type" => "array",
               "items" => %{"type" => "string"}
             }

      assert result["parameters"]["properties"]["metadata"] == %{
               "type" => "array",
               "items" => %{
                 "type" => "object",
                 "properties" => %{
                   "key" => %{"type" => "string"},
                   "value" => %{"type" => "string"}
                 },
                 "additionalProperties" => false,
                 "required" => ["key", "value"]
               }
             }
    end
  end
end
