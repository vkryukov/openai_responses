defmodule OpenAI.Responses.PricingTest do
  use ExUnit.Case
  alias OpenAI.Responses.Pricing

  describe "get_pricing/1" do
    test "returns pricing for known models" do
      pricing1 = Pricing.get_pricing("gpt-4.1-mini-2025-04-14")
      assert Decimal.equal?(pricing1.input, Decimal.new("0.40"))
      assert Decimal.equal?(pricing1.cached_input, Decimal.new("0.10"))
      assert Decimal.equal?(pricing1.output, Decimal.new("1.60"))

      pricing2 = Pricing.get_pricing("o3-2025-04-16")
      assert Decimal.equal?(pricing2.input, Decimal.new("10.00"))
      assert Decimal.equal?(pricing2.cached_input, Decimal.new("2.50"))
      assert Decimal.equal?(pricing2.output, Decimal.new("40.00"))

      pricing3 = Pricing.get_pricing("o1-pro-2025-03-19")
      assert Decimal.equal?(pricing3.input, Decimal.new("150.00"))
      assert pricing3.cached_input == nil
      assert Decimal.equal?(pricing3.output, Decimal.new("600.00"))
    end

    test "returns nil for unknown models" do
      assert Pricing.get_pricing("unknown-model") == nil
      assert Pricing.get_pricing("gpt-5") == nil
    end

    test "handles models without cached pricing" do
      pricing = Pricing.get_pricing("gpt-4o-2024-05-13")
      assert pricing.cached_input == nil
      assert Decimal.equal?(pricing.input, Decimal.new("5.00"))
      assert Decimal.equal?(pricing.output, Decimal.new("15.00"))
    end

    test "handles models without output pricing" do
      pricing = Pricing.get_pricing("gpt-image-1")
      assert pricing.output == nil
      assert Decimal.equal?(pricing.input, Decimal.new("5.00"))
      assert Decimal.equal?(pricing.cached_input, Decimal.new("1.25"))
    end
  end

  describe "list_models/0" do
    test "returns a list of all model names" do
      models = Pricing.list_models()

      assert is_list(models)
      assert "gpt-4.1-mini-2025-04-14" in models
      assert "o3-2025-04-16" in models
      assert "o1-pro-2025-03-19" in models
      assert "gpt-4o-2024-08-06" in models
    end

    test "includes all model variants" do
      models = Pricing.list_models()

      # Check that we have both base models and dated variants
      assert "gpt-4.1" in models
      assert "gpt-4.1-2025-04-14" in models

      assert "o3" in models
      assert "o3-2025-04-16" in models
    end
  end
end
