defmodule OpenAI.ResponsesTest do
  use ExUnit.Case
  doctest OpenAI.Responses

  alias OpenAI.Responses
  alias OpenAI.Responses.Client
  alias OpenAI.Responses.Helpers
  alias OpenAI.Responses.Schema

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

  describe "create/1" do
    @tag :integration
    test "successfully creates a response (integration)" do
      opts = [model: "gpt-test", input: "Hello"]
      assert {:ok, _response} = Responses.create(opts)
    end

    @tag :integration
    test "returns error on client failure (integration)" do
      opts = [model: "invalid-model-for-error", input: "Hello"]
      assert {:error, _reason} = Responses.create(opts)
    end

    test "raises KeyError if :model is missing" do
      opts = [input: "Hello"]

      assert_raise KeyError, ~r/key :model not found/, fn ->
        Responses.create(opts)
      end
    end

    test "raises KeyError if :input is missing" do
      opts = [model: "gpt-test"]

      assert_raise KeyError, ~r/key :input not found/, fn ->
        Responses.create(opts)
      end
    end
  end

  describe "stream/1" do
    @tag :integration
    test "successfully creates a stream (integration)" do
      opts = [model: "gpt-stream", input: "Stream me"]
      stream = Responses.stream(opts)
      assert %Stream{} = stream
    end

    test "stream raises KeyError if :model is missing during consumption" do
      opts = [input: "Stream me"]
      stream = Responses.stream(opts)

      assert_raise KeyError, ~r/key :model not found/, fn ->
        Enum.to_list(stream)
      end
    end

    test "stream raises KeyError if :input is missing during consumption" do
      opts = [model: "gpt-stream"]
      stream = Responses.stream(opts)

      assert_raise KeyError, ~r/key :input not found/, fn ->
        Enum.to_list(stream)
      end
    end
  end

  describe "parse/2" do
    @tag :integration
    test "successfully parses structured output (integration)" do
      schema = Schema.object(%{name: :string, age: :integer})

      opts = [
        model: "gpt-parse",
        input: "John is 30",
        schema_name: "person",
        instructions: "Extract the person information as JSON matching the 'person' schema."
      ]

      assert {:ok, result} = Responses.parse(schema, opts)
      assert is_map(result.parsed)
      assert result.parsed["name"] == "John"
      assert result.parsed["age"] == 30
      assert is_map(result.raw_response)
      assert is_map(result.token_usage) or is_nil(result.token_usage)
    end

    test "parse raises KeyError if :model is missing" do
      schema = Schema.object(%{name: :string})
      opts = [input: "Test"]

      assert_raise KeyError, ~r/key :model not found/, fn ->
        Responses.parse(schema, opts)
      end
    end

    test "parse raises KeyError if :input is missing" do
      schema = Schema.object(%{name: :string})
      opts = [model: "gpt-test"]

      assert_raise KeyError, ~r/key :input not found/, fn ->
        Responses.parse(schema, opts)
      end
    end

    @tag :integration
    test "parse returns error if response JSON is invalid (integration, if possible)" do
      schema = Schema.object(%{name: :string})

      opts = [
        model: "gpt-test",
        input: "This is not likely to produce the desired JSON.",
        instructions: "Extract name as JSON matching the schema. Gibberish is fine."
      ]

      case Responses.parse(schema, opts) do
        {:ok, result} ->
          refute result.parsed["name"]

        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    @tag :skip
    test "parse returns error if response format is unexpected" do
      _schema = Schema.object(%{name: :string})

      _opts = [
        model: "gpt-parse",
        input: "Format",
        instructions: "Extract name"
      ]
    end
  end

  describe "get/2" do
    @tag :integration
    @tag :skip
    test "successfully retrieves a response (integration)" do
      response_id = "res_needs_real_id"
      opts = []
      assert {:ok, response} = Responses.get(response_id, opts)
      assert response["id"] == response_id
    end

    @tag :integration
    @tag :skip
    test "successfully retrieves a response with include option (integration)" do
      response_id = "res_needs_real_id_with_usage"
      opts = [include: ["usage"]]
      assert {:ok, response} = Responses.get(response_id, opts)
      assert response["id"] == response_id
      assert is_map(response["usage"])
    end
  end

  describe "delete/1" do
    @tag :integration
    @tag :skip
    test "successfully deletes a response (integration)" do
      response_id = "res_needs_real_id_to_delete"
      opts = []
      assert {:ok, result} = Responses.delete(response_id, opts)
      assert result["id"] == response_id
      assert result["deleted"] == true
    end
  end

  describe "list_input_items/2" do
    @tag :integration
    @tag :skip
    test "successfully lists input items (integration)" do
      response_id = "res_needs_real_id_to_list"
      opts = [limit: 10, order: "asc"]
      assert {:ok, items} = Responses.list_input_items(response_id, opts)
      assert is_list(items["data"])
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
