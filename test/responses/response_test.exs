defmodule OpenAI.Responses.ResponseTest do
  use ExUnit.Case
  alias OpenAI.Responses.Response

  describe "extract_text/1" do
    test "extracts text from a single output_text response" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "role" => "assistant",
              "content" => [
                %{
                  "type" => "output_text",
                  "text" => "Hello, world!"
                }
              ]
            }
          ]
        }
      }

      result = Response.extract_text(response)
      assert result.text == "Hello, world!"
    end

    test "extracts text from multiple output_text responses" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "role" => "assistant",
              "content" => [
                %{
                  "type" => "output_text",
                  "text" => "First message"
                }
              ]
            },
            %{
              "role" => "assistant",
              "content" => [
                %{
                  "type" => "output_text",
                  "text" => "Second message"
                }
              ]
            }
          ]
        }
      }

      result = Response.extract_text(response)
      assert result.text == "First message\nSecond message"
    end

    test "ignores responses that are not from an assistant" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "role" => "user",
              "content" => [
                %{
                  "type" => "output_text",
                  "text" => "User message"
                }
              ]
            },
            %{
              "role" => "assistant",
              "content" => [
                %{
                  "type" => "output_text",
                  "text" => "Assistant message"
                }
              ]
            },
            %{
              "role" => "system",
              "content" => [
                %{
                  "type" => "output_text",
                  "text" => "System message"
                }
              ]
            }
          ]
        }
      }

      result = Response.extract_text(response)
      assert result.text == "Assistant message"
    end

    test "ignores content that is not output_text type" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "role" => "assistant",
              "content" => [
                %{
                  "type" => "image",
                  "text" => "Should be ignored"
                },
                %{
                  "type" => "output_text",
                  "text" => "Should be included"
                },
                %{
                  "type" => "other",
                  "text" => "Should be ignored"
                }
              ]
            }
          ]
        }
      }

      result = Response.extract_text(response)
      assert result.text == "Should be included"
    end

    test "handles multiple content items of output_text type in a single response" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "role" => "assistant",
              "content" => [
                %{
                  "type" => "output_text",
                  "text" => "First part"
                },
                %{
                  "type" => "output_text",
                  "text" => "Second part"
                }
              ]
            }
          ]
        }
      }

      result = Response.extract_text(response)
      assert result.text == "First part\nSecond part"
    end

    test "handles missing output key" do
      response = %Response{
        body: %{}
      }

      result = Response.extract_text(response)
      assert result.text == ""
    end

    test "handles missing content key" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "role" => "assistant"
            }
          ]
        }
      }

      result = Response.extract_text(response)
      assert result.text == ""
    end

    test "handles missing text key in content" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "role" => "assistant",
              "content" => [
                %{
                  "type" => "output_text"
                }
              ]
            }
          ]
        }
      }

      result = Response.extract_text(response)
      assert result.text == ""
    end

    test "handles empty output array" do
      response = %Response{
        body: %{
          "output" => []
        }
      }

      result = Response.extract_text(response)
      assert result.text == ""
    end

    test "handles empty content array" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "role" => "assistant",
              "content" => []
            }
          ]
        }
      }

      result = Response.extract_text(response)
      assert result.text == ""
    end
  end

  describe "extract_json/1" do
    test "parses JSON from text when response has structured format" do
      response = %Response{
        text: ~s({"name": "John", "age": 30}),
        body: %{
          "text" => %{
            "format" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{
                  "name" => %{"type" => "string"},
                  "age" => %{"type" => "number"}
                }
              }
            }
          }
        }
      }

      result = Response.extract_json(response)
      assert result.parsed == %{"name" => "John", "age" => 30}
      assert result.parse_error == nil
    end

    test "sets parse_error when JSON is invalid" do
      response = %Response{
        text: ~s({"name": "John", "age":}),
        body: %{
          "text" => %{
            "format" => %{
              "schema" => %{
                "type" => "object"
              }
            }
          }
        }
      }

      result = Response.extract_json(response)
      assert result.parsed == nil
      assert is_map(result.parse_error)
      assert Map.has_key?(result.parse_error, :json)
      assert is_binary(result.parse_error.json)
    end

    test "preserves other fields in the response struct" do
      response = %Response{
        text: ~s({"name": "John"}),
        cost: %{total: 0.01},
        body: %{
          "text" => %{
            "format" => %{
              "schema" => %{
                "type" => "object"
              }
            }
          }
        }
      }

      result = Response.extract_json(response)
      assert result.parsed == %{"name" => "John"}
      assert result.cost == %{total: 0.01}
      assert result.body == response.body
      assert result.text == response.text
    end

    test "handles empty text" do
      response = %Response{
        text: "",
        body: %{}
      }

      result = Response.extract_json(response)
      assert result.parsed == nil
      assert result.parse_error == nil
    end
  end

  describe "extract_function_calls/1" do
    test "extracts function calls from response output" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "id" => "fc_12345xyz",
              "call_id" => "call_12345xyz",
              "type" => "function_call",
              "name" => "get_weather",
              "arguments" => "{\"location\":\"Paris, France\"}"
            },
            %{
              "id" => "fc_67890abc",
              "call_id" => "call_67890abc",
              "type" => "function_call",
              "name" => "get_weather",
              "arguments" => "{\"location\":\"Bogotá, Colombia\"}"
            }
          ]
        }
      }

      result = Response.extract_function_calls(response)
      
      assert length(result.function_calls) == 2
      assert Enum.at(result.function_calls, 0) == %{
        name: "get_weather",
        call_id: "call_12345xyz",
        arguments: %{"location" => "Paris, France"}
      }
      assert Enum.at(result.function_calls, 1) == %{
        name: "get_weather",
        call_id: "call_67890abc",
        arguments: %{"location" => "Bogotá, Colombia"}
      }
      assert result.parse_error == nil
    end

    test "handles function calls with complex arguments" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "id" => "fc_99999def",
              "call_id" => "call_99999def",
              "type" => "function_call",
              "name" => "send_email",
              "arguments" => "{\"to\":\"bob@email.com\",\"body\":\"Hi bob\",\"options\":{\"priority\":\"high\",\"delay\":30}}"
            }
          ]
        }
      }

      result = Response.extract_function_calls(response)
      
      assert length(result.function_calls) == 1
      assert Enum.at(result.function_calls, 0) == %{
        name: "send_email",
        call_id: "call_99999def",
        arguments: %{
          "to" => "bob@email.com",
          "body" => "Hi bob",
          "options" => %{"priority" => "high", "delay" => 30}
        }
      }
    end

    test "handles invalid JSON in function call arguments" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "id" => "fc_invalid",
              "call_id" => "call_invalid",
              "type" => "function_call",
              "name" => "broken_call",
              "arguments" => "{\"invalid\": json}"
            },
            %{
              "id" => "fc_valid",
              "call_id" => "call_valid",
              "type" => "function_call",
              "name" => "valid_call",
              "arguments" => "{\"valid\": \"json\"}"
            }
          ]
        }
      }

      result = Response.extract_function_calls(response)
      
      assert length(result.function_calls) == 1
      assert Enum.at(result.function_calls, 0) == %{
        name: "valid_call",
        call_id: "call_valid",
        arguments: %{"valid" => "json"}
      }
      
      assert is_map(result.parse_error)
      assert Map.has_key?(result.parse_error, :function_calls)
      assert length(result.parse_error.function_calls) == 1
      assert String.contains?(Enum.at(result.parse_error.function_calls, 0), "broken_call")
    end

    test "ignores non-function_call output types" do
      response = %Response{
        body: %{
          "output" => [
            %{
              "role" => "assistant",
              "content" => [
                %{
                  "type" => "output_text",
                  "text" => "Hello, world!"
                }
              ]
            },
            %{
              "id" => "fc_12345xyz",
              "call_id" => "call_12345xyz",
              "type" => "function_call",
              "name" => "get_weather",
              "arguments" => "{\"location\":\"Paris\"}"
            }
          ]
        }
      }

      result = Response.extract_function_calls(response)
      
      assert length(result.function_calls) == 1
      assert Enum.at(result.function_calls, 0).name == "get_weather"
    end

    test "handles empty output array" do
      response = %Response{
        body: %{
          "output" => []
        }
      }

      result = Response.extract_function_calls(response)
      assert result.function_calls == []
      assert result.parse_error == nil
    end

    test "handles missing output key" do
      response = %Response{
        body: %{}
      }

      result = Response.extract_function_calls(response)
      assert result.function_calls == []
      assert result.parse_error == nil
    end

    test "does not re-extract if function_calls already present" do
      response = %Response{
        function_calls: [%{name: "existing", call_id: "call_123", arguments: %{}}],
        body: %{
          "output" => [
            %{
              "id" => "fc_new",
              "call_id" => "call_new",
              "type" => "function_call",
              "name" => "new_call",
              "arguments" => "{\"new\": \"data\"}"
            }
          ]
        }
      }

      result = Response.extract_function_calls(response)
      
      # Should preserve existing function_calls
      assert length(result.function_calls) == 1
      assert Enum.at(result.function_calls, 0).name == "existing"
    end

    test "preserves existing parse_error when adding function call errors" do
      response = %Response{
        parse_error: %{json: "existing json error"},
        body: %{
          "output" => [
            %{
              "id" => "fc_invalid",
              "call_id" => "call_invalid",
              "type" => "function_call",
              "name" => "broken_call",
              "arguments" => "{invalid json}"
            }
          ]
        }
      }

      result = Response.extract_function_calls(response)
      
      assert result.parse_error.json == "existing json error"
      assert Map.has_key?(result.parse_error, :function_calls)
      assert length(result.parse_error.function_calls) == 1
    end
  end
end
