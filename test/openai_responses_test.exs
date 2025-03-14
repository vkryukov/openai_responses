defmodule OpenAI.ResponsesTest do
  use ExUnit.Case
  doctest OpenAI.Responses

  alias OpenAI.Responses.Helpers

  describe "Responses module structure" do
    test "modules are properly defined" do
      assert Code.ensure_loaded?(OpenAI.Responses)
      assert Code.ensure_loaded?(OpenAI.Responses.Client)
      assert Code.ensure_loaded?(OpenAI.Responses.Config)
      assert Code.ensure_loaded?(OpenAI.Responses.Types)
      assert Code.ensure_loaded?(OpenAI.Responses.Helpers)
      assert Code.ensure_loaded?(OpenAI.Responses.Stream)
    end
  end
  
  describe "helpers" do
    test "output_text extracts text from response" do
      response = %{
        "output" => [
          %{
            "type" => "message",
            "content" => [
              %{"type" => "output_text", "text" => "Hello world"}
            ]
          }
        ]
      }
      
      assert Helpers.output_text(response) == "Hello world"
    end
    
    test "output_text handles multiple messages" do
      response = %{
        "output" => [
          %{
            "type" => "message",
            "content" => [
              %{"type" => "output_text", "text" => "First message"}
            ]
          },
          %{
            "type" => "message",
            "content" => [
              %{"type" => "output_text", "text" => "Second message"}
            ]
          }
        ]
      }
      
      assert Helpers.output_text(response) == "First message\nSecond message"
    end
    
    test "token_usage extracts usage information" do
      response = %{
        "usage" => %{
          "input_tokens" => 10,
          "output_tokens" => 20,
          "total_tokens" => 30
        }
      }
      
      assert Helpers.token_usage(response) == %{
        "input_tokens" => 10,
        "output_tokens" => 20,
        "total_tokens" => 30
      }
    end
    
    test "has_refusal? detects refusals" do
      response_with_refusal = %{
        "output" => [
          %{
            "type" => "message",
            "content" => [
              %{"type" => "refusal", "refusal" => "I cannot help with that request"}
            ]
          }
        ]
      }
      
      response_without_refusal = %{
        "output" => [
          %{
            "type" => "message",
            "content" => [
              %{"type" => "output_text", "text" => "Here's your answer"}
            ]
          }
        ]
      }
      
      assert Helpers.has_refusal?(response_with_refusal) == true
      assert Helpers.has_refusal?(response_without_refusal) == false
    end
  end
end