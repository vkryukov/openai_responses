defmodule OpenAI.Responses.HelpersTest do
  use ExUnit.Case, async: true

  alias OpenAI.Responses.Helpers

  describe "calculate_cost/2" do
    test "calculates cost for gpt-4o with cached input" do
      usage = %{
        "input_tokens" => 1000,
        "input_tokens_details" => %{"cached_tokens" => 500},
        "output_tokens" => 2000
      }

      # Expected: (500 * 1.25 / 1M) + (500 * 2.50 / 1M) + (2000 * 10.00 / 1M)
      # = 0.000625 + 0.00125 + 0.02 = 0.021875
      expected_cost = Decimal.new("0.021875")

      # Test using the alias
      assert {:ok, cost} = Helpers.calculate_cost("gpt-4o", usage)
      assert Decimal.equal?(cost, expected_cost)
    end

    test "calculates cost for gpt-4o without cached input" do
      usage = %{
        "input_tokens" => 1000,
        "input_tokens_details" => %{"cached_tokens" => 0},
        "output_tokens" => 2000
      }

      # Expected: (1000 * 2.50 / 1M) + (2000 * 10.00 / 1M)
      # = 0.0025 + 0.02 = 0.0225
      expected_cost = Decimal.new("0.0225")

      # Test using the full name
      assert {:ok, cost} = Helpers.calculate_cost("gpt-4o-2024-08-06", usage)
      assert Decimal.equal?(cost, expected_cost)
    end

    test "calculates cost using long model name (gpt-4o-mini)" do
      usage = %{
        "input_tokens" => 500,
        "input_tokens_details" => %{"cached_tokens" => 100},
        "output_tokens" => 1000
      }

      # Expected: (100 * 0.075 / 1M) + (400 * 0.15 / 1M) + (1000 * 0.60 / 1M)
      # = 0.0000075 + 0.00006 + 0.0006 = 0.0006675
      expected_cost = Decimal.new("0.0006675")

      # Test using the alias
      assert {:ok, cost} = Helpers.calculate_cost("gpt-4o-mini", usage)
      assert Decimal.equal?(cost, expected_cost)

      # Test using the full name
      assert {:ok, cost_full} = Helpers.calculate_cost("gpt-4o-mini-2024-07-18", usage)
      assert Decimal.equal?(cost_full, expected_cost)
    end

    test "calculates cost for model without specific cached discount (gpt-4o-audio-preview)" do
      usage = %{
        "input_tokens" => 1000,
        "input_tokens_details" => %{"cached_tokens" => 500},
        "output_tokens" => 2000
      }

      # Expected: (500 * 2.50 / 1M) + (500 * 2.50 / 1M) + (2000 * 10.00 / 1M)
      # = 0.00125 + 0.00125 + 0.02 = 0.0225
      expected_cost = Decimal.new("0.0225")

      # Test using the alias
      assert {:ok, cost} = Helpers.calculate_cost("gpt-4o-audio-preview", usage)
      assert Decimal.equal?(cost, expected_cost)

      # Test using the full name
      assert {:ok, cost_full} = Helpers.calculate_cost("gpt-4o-audio-preview-2024-12-17", usage)
      assert Decimal.equal?(cost_full, expected_cost)
    end

    test "returns :unknown for unlisted model" do
      usage = %{
        "input_tokens" => 100,
        "input_tokens_details" => %{"cached_tokens" => 0},
        "output_tokens" => 50
      }

      assert Helpers.calculate_cost("some-random-model-x", usage) == {:error, :unknown_model_name}
    end

    test "returns error for invalid usage format (missing keys)" do
      usage = %{"input_tokens" => 100}
      assert Helpers.calculate_cost("gpt-4o", usage) == {:error, :invalid_usage_format}
    end

    test "returns error for invalid usage format (wrong types)" do
      usage = %{
        "input_tokens" => "1000",
        "input_tokens_details" => %{"cached_tokens" => 500},
        "output_tokens" => 2000
      }

      assert Helpers.calculate_cost("gpt-4o", usage) == {:error, :invalid_usage_format}
    end
  end

  describe "calculate_cost/1" do
    test "calculates cost from raw response map" do
      raw_response = %{
        "model" => "gpt-4o-mini",
        "usage" => %{
          "input_tokens" => 500,
          "input_tokens_details" => %{"cached_tokens" => 100},
          "output_tokens" => 1000
        },
        "output" => [
          %{"type" => "message", "content" => [%{"type" => "output_text", "text" => "..."}]}
        ]
      }

      # Expected from previous test: 0.0006675
      expected_cost = Decimal.new("0.0006675")

      assert {:ok, cost} = Helpers.calculate_cost(raw_response)
      assert Decimal.equal?(cost, expected_cost)
    end

    test "returns :unknown from raw response map" do
      raw_response = %{
        "model" => "unknown-model",
        "usage" => %{
          "input_tokens" => 100,
          "input_tokens_details" => %{"cached_tokens" => 0},
          "output_tokens" => 50
        }
      }

      assert Helpers.calculate_cost(raw_response) == {:error, :unknown_model_name}
    end

    test "returns error for invalid raw response format (missing model)" do
      raw_response = %{
        "usage" => %{
          "input_tokens" => 100,
          "input_tokens_details" => %{"cached_tokens" => 0},
          "output_tokens" => 50
        }
      }

      assert Helpers.calculate_cost(raw_response) == {:error, :invalid_response_format}
    end

    test "returns error for invalid raw response format (missing usage)" do
      raw_response = %{"model" => "gpt-4o"}
      assert Helpers.calculate_cost(raw_response) == {:error, :invalid_response_format}
    end

    test "returns error for invalid usage format within raw response" do
      raw_response = %{
        "model" => "gpt-4o",
        "usage" => %{"input_tokens" => 100}
      }

      assert Helpers.calculate_cost(raw_response) == {:error, :invalid_usage_format}
    end
  end
end
