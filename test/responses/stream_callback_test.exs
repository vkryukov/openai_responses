defmodule OpenAI.Responses.StreamCallbackTest do
  use ExUnit.Case

  alias OpenAI.Responses
  alias OpenAI.Responses.Response

  describe "create/1 with stream callback" do
    @tag :api
    test "returns proper Response struct with text extraction and cost calculation" do
      _events = []

      {:ok, response} =
        Responses.create(
          input: "Say exactly 'Hello streaming world'",
          stream: fn
            {:ok, %{event: _event}} ->
              # Just acknowledge the event
              :ok

            _ ->
              :ok
          end
        )

      assert %Response{} = response
      assert response.text == "Hello streaming world"
      assert response.body["model"] =~ "gpt"
      assert response.body["usage"]["input_tokens"] > 0
      assert response.body["usage"]["output_tokens"] > 0

      assert %{
               input_cost: input_cost,
               output_cost: output_cost,
               total_cost: total_cost
             } = response.cost

      assert Decimal.gt?(input_cost, Decimal.new(0))
      assert Decimal.gt?(output_cost, Decimal.new(0))
      assert Decimal.gt?(total_cost, Decimal.new(0))
    end

    @tag :api
    test "works with structured output" do
      {:ok, response} =
        Responses.create(
          input: "Generate a person with name and age",
          schema: %{
            name: :string,
            age: :integer
          },
          stream: fn _ -> :ok end
        )

      assert %Response{} = response
      assert response.text =~ "{"
      assert is_map(response.parsed)
      assert is_binary(response.parsed["name"])
      assert is_integer(response.parsed["age"])
      assert is_nil(response.parse_error)
    end

    @tag :api
    test "handles errors gracefully" do
      result =
        Responses.create(
          input: "Test",
          model: "non-existent-model",
          stream: fn _ -> :ok end
        )

      assert {:error, _} = result
    end

    @tag :api
    test "callback can stop streaming early" do
      _message_count = 0

      {:ok, response} =
        Responses.create(
          input: "Count from 1 to 100",
          stream: fn
            {:ok, %{event: "response.output_text.delta"}} ->
              # Stop after first text delta
              {:error, :stopped_early}

            _ ->
              :ok
          end
        )

      # Should still return a valid response even if stopped early
      assert %Response{} = response
      assert response.body["status"] == "completed"
    end
  end
end
