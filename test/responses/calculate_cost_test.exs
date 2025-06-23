defmodule OpenAI.Responses.CalculateCostTest do
  use ExUnit.Case
  alias OpenAI.Responses.Response

  # Helper to compare decimal costs
  defp assert_cost_equals(actual, expected) do
    assert Decimal.equal?(actual.input_cost, Decimal.new(expected.input_cost))
    assert Decimal.equal?(actual.output_cost, Decimal.new(expected.output_cost))
    assert Decimal.equal?(actual.total_cost, Decimal.new(expected.total_cost))
    assert Decimal.equal?(actual.cached_discount, Decimal.new(expected.cached_discount))
  end

  describe "calculate_cost/1" do
    test "calculates cost for a model with regular input and output tokens" do
      response = %Response{
        body: %{
          "model" => "gpt-4.1-mini-2025-04-14",
          "usage" => %{
            "input_tokens" => 1000,
            "output_tokens" => 500,
            "input_tokens_details" => %{"cached_tokens" => 0}
          }
        }
      }

      result = Response.calculate_cost(response)

      assert_cost_equals(result.cost, %{
        # 1000 tokens * $0.40 per million
        input_cost: "0.0004",
        # 500 tokens * $1.60 per million
        output_cost: "0.0008",
        total_cost: "0.0012",
        cached_discount: "0"
      })
    end

    test "calculates cost with cached input tokens" do
      response = %Response{
        body: %{
          "model" => "gpt-4o-2024-08-06",
          "usage" => %{
            "input_tokens" => 2000,
            "output_tokens" => 1000,
            "input_tokens_details" => %{"cached_tokens" => 1000}
          }
        }
      }

      result = Response.calculate_cost(response)

      # 1000 regular tokens at $2.50 per million = 0.0025
      # 1000 cached tokens at $1.25 per million = 0.00125
      # 1000 output tokens at $10.00 per million = 0.01
      # cached discount = 1000 * (2.50 - 1.25) / 1000000 = 0.00125
      assert_cost_equals(result.cost, %{
        # 0.0025 + 0.00125
        input_cost: "0.00375",
        output_cost: "0.01",
        total_cost: "0.01375",
        cached_discount: "0.00125"
      })
    end

    test "handles model without cached pricing" do
      response = %Response{
        body: %{
          "model" => "gpt-4o-2024-05-13",
          "usage" => %{
            "input_tokens" => 1000,
            "output_tokens" => 500,
            "input_tokens_details" => %{"cached_tokens" => 500}
          }
        }
      }

      result = Response.calculate_cost(response)

      # This model has no cached_input price, so all input tokens use regular pricing
      assert_cost_equals(result.cost, %{
        # 1000 tokens * $5.00 per million
        input_cost: "0.005",
        # 500 tokens * $15.00 per million
        output_cost: "0.0075",
        total_cost: "0.0125",
        cached_discount: "0"
      })
    end

    test "handles model without output pricing (image generation)" do
      response = %Response{
        body: %{
          "model" => "gpt-image-1",
          "usage" => %{
            "input_tokens" => 500,
            "output_tokens" => 0,
            "input_tokens_details" => %{"cached_tokens" => 0}
          }
        }
      }

      result = Response.calculate_cost(response)

      assert_cost_equals(result.cost, %{
        # 500 tokens * $5.00 per million
        input_cost: "0.0025",
        output_cost: "0",
        total_cost: "0.0025",
        cached_discount: "0"
      })
    end

    test "handles expensive model (o1-pro)" do
      response = %Response{
        body: %{
          "model" => "o1-pro-2025-03-19",
          "usage" => %{
            "input_tokens" => 10_000,
            "output_tokens" => 5000,
            "input_tokens_details" => %{"cached_tokens" => 0}
          }
        }
      }

      result = Response.calculate_cost(response)

      assert_cost_equals(result.cost, %{
        # 10000 tokens * $150.00 per million
        input_cost: "1.5",
        # 5000 tokens * $600.00 per million
        output_cost: "3.0",
        total_cost: "4.5",
        cached_discount: "0"
      })
    end

    test "handles missing usage information" do
      response = %Response{
        body: %{
          "model" => "gpt-4.1-mini-2025-04-14"
        }
      }

      result = Response.calculate_cost(response)

      assert_cost_equals(result.cost, %{
        input_cost: "0",
        output_cost: "0",
        total_cost: "0",
        cached_discount: "0"
      })
    end

    test "handles missing model information" do
      response = %Response{
        body: %{
          "usage" => %{
            "input_tokens" => 1000,
            "output_tokens" => 500
          }
        }
      }

      result = Response.calculate_cost(response)

      assert_cost_equals(result.cost, %{
        input_cost: "0",
        output_cost: "0",
        total_cost: "0",
        cached_discount: "0"
      })
    end

    test "handles unknown model" do
      response = %Response{
        body: %{
          "model" => "unknown-model-xyz",
          "usage" => %{
            "input_tokens" => 1000,
            "output_tokens" => 500
          }
        }
      }

      result = Response.calculate_cost(response)

      assert_cost_equals(result.cost, %{
        input_cost: "0",
        output_cost: "0",
        total_cost: "0",
        cached_discount: "0"
      })
    end

    test "handles missing input_tokens_details" do
      response = %Response{
        body: %{
          "model" => "gpt-4.1-mini-2025-04-14",
          "usage" => %{
            "input_tokens" => 1000,
            "output_tokens" => 500
          }
        }
      }

      result = Response.calculate_cost(response)

      # Should treat all input tokens as regular (non-cached)
      assert_cost_equals(result.cost, %{
        # 1000 tokens * $0.40 per million
        input_cost: "0.0004",
        # 500 tokens * $1.60 per million
        output_cost: "0.0008",
        total_cost: "0.0012",
        cached_discount: "0"
      })
    end

    test "handles zero tokens" do
      response = %Response{
        body: %{
          "model" => "gpt-4.1-mini-2025-04-14",
          "usage" => %{
            "input_tokens" => 0,
            "output_tokens" => 0,
            "input_tokens_details" => %{"cached_tokens" => 0}
          }
        }
      }

      result = Response.calculate_cost(response)

      assert_cost_equals(result.cost, %{
        input_cost: "0",
        output_cost: "0",
        total_cost: "0",
        cached_discount: "0"
      })
    end

    test "preserves other fields in the response struct" do
      response = %Response{
        text: "some text",
        parsed: %{"some" => "data"},
        body: %{
          "model" => "gpt-4.1-mini-2025-04-14",
          "usage" => %{
            "input_tokens" => 1000,
            "output_tokens" => 500,
            "input_tokens_details" => %{"cached_tokens" => 0}
          }
        }
      }

      result = Response.calculate_cost(response)

      assert result.text == "some text"
      assert result.parsed == %{"some" => "data"}
      assert result.body == response.body
      assert is_map(result.cost)
    end

    test "calculates correct cost for o3 model" do
      response = %Response{
        body: %{
          "model" => "o3-2025-04-16",
          "usage" => %{
            "input_tokens" => 100_000,
            "output_tokens" => 50_000,
            "input_tokens_details" => %{"cached_tokens" => 40_000}
          }
        }
      }

      result = Response.calculate_cost(response)

      # 60000 regular tokens at $10.00 per million = 0.6
      # 40000 cached tokens at $2.50 per million = 0.1
      # 50000 output tokens at $40.00 per million = 2.0
      # cached discount = 40000 * (10.00 - 2.50) / 1000000 = 0.3
      assert_cost_equals(result.cost, %{
        # 0.6 + 0.1
        input_cost: "0.140",
        output_cost: "0.400",
        total_cost: "0.540",
        cached_discount: "0.060"
      })
    end

    test "returns zero costs for model without pricing data" do
      response = %Response{
        body: %{
          "model" => "some-new-model-without-pricing",
          "usage" => %{
            "input_tokens" => 5000,
            "output_tokens" => 3000,
            "input_tokens_details" => %{"cached_tokens" => 1000}
          }
        }
      }

      result = Response.calculate_cost(response)

      # Even with usage data, if pricing is not available, return zero costs
      assert_cost_equals(result.cost, %{
        input_cost: "0",
        output_cost: "0",
        total_cost: "0",
        cached_discount: "0"
      })
    end
  end
end
