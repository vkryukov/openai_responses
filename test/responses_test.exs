defmodule OpenAI.ResponsesTest do
  use ExUnit.Case

  alias OpenAI.Responses

  @tag :api
  test "create with a string argument should use default model" do
    response = Responses.create!("Respond with exactly 5 words including the word 'elixir'")
    response_text = response.text

    assert response_text =~ ~r/elixir/i
    # Check that response is reasonably short (3-7 words) instead of exactly 5
    word_count = String.split(response_text, " ") |> Enum.count()
    assert word_count >= 3 and word_count <= 7
    assert response.body["model"] =~ ~r/gpt.*mini/
  end

  @tag :api
  test "create with an input and model arguments uses the correct model" do
    response =
      Responses.create!(
        input: "Write a haiku about Elixir programming language",
        model: "gpt-4o"
      )

    assert String.split(response.text, "\n") |> Enum.count() == 3
    assert response.body["model"] =~ ~r/gpt-4o/
    # Ensure it's not using the default model
    refute response.body["model"] =~ ~r/gpt-4\.1-mini/
  end

  @tag :api
  test "create with a map argument" do
    response =
      Responses.create!(%{
        input: "Reply with exactly three words about Elixir",
        model: "gpt-4o"
      })

    assert String.split(response.text, " ") |> Enum.count() == 3
    assert response.body["model"] =~ ~r/gpt-4o/
  end

  @tag :api
  test "create with a map including stream callback" do
    collected_text = Agent.start_link(fn -> "" end) |> elem(1)

    {:ok, response} =
      Responses.create(%{
        input: "Count from 1 to 3",
        stream: fn
          {:ok, %{event: "response.output_text.delta", data: %{"delta" => text}}} ->
            Agent.update(collected_text, &(&1 <> text))
            :ok

          _ ->
            :ok
        end
      })

    final_text = Agent.get(collected_text, & &1)
    Agent.stop(collected_text)

    assert response.text != nil
    assert final_text =~ ~r/1.*2.*3/s
  end

  @tag :api
  test "create with a map with atom and string keys" do
    # Maps with mixed atom and string keys should work
    response =
      Responses.create!(%{
        "input" => "Reply with exactly two words",
        :model => "gpt-4o"
      })

    assert String.split(response.text, " ") |> Enum.count() == 2
    assert response.body["model"] =~ ~r/gpt-4o/
  end

  @tag :api
  test "list_models returns available models" do
    models = Responses.list_models()

    assert is_list(models)
    assert length(models) > 0
    assert Enum.all?(models, &Map.has_key?(&1, "id"))
  end

  @tag :api
  test "list_models with match filter returns filtered models" do
    gpt_models = Responses.list_models("gpt")

    assert is_list(gpt_models)
    assert Enum.all?(gpt_models, &(&1["id"] =~ "gpt"))
  end

  @tag :api
  test "create with invalid parameter returns error" do
    result = Responses.create(nonsensical_param: "invalid value", input: "test")

    assert {:error, error} = result
    assert is_map(error)
  end

  @tag :api
  test "create with invalid model returns error" do
    result = Responses.create(input: "test", model: "non-existent-model-xyz")

    assert {:error, error} = result
    assert is_map(error)
  end

  @tag :api
  test "response can be piped to create a follow up response" do
    response = Responses.create!("Write a haiku about Elixir programming language")
    follow_up_response = response |> Responses.create!(input: "What is this haiku about?")

    assert follow_up_response.text =~ ~r/Elixir/
  end

  @tag :api
  test "create/2 preserves model from previous response when not explicitly provided" do
    # Create initial response with a specific model
    initial_response =
      Responses.create!(
        input: "Say hello",
        model: "gpt-4o"
      )

    # Verify the initial response uses the specified model
    assert initial_response.body["model"] =~ ~r/gpt-4o/

    # Create follow-up without specifying model
    follow_up_response = Responses.create!(initial_response, input: "Say goodbye")

    # The follow-up should use the same model as the initial response
    assert follow_up_response.body["model"] == initial_response.body["model"]
  end

  @tag :api
  test "create/2 accepts maps for options" do
    # Create initial response
    initial_response = Responses.create!("Say hello")

    # Create follow-up with map options
    follow_up_response =
      Responses.create!(initial_response, %{
        input: "Say goodbye in exactly two words",
        temperature: 0.5
      })

    assert String.split(follow_up_response.text, " ") |> Enum.count() == 2
    assert follow_up_response.body["previous_response_id"] == initial_response.body["id"]
  end

  @tag :api
  test "create/2 allows overriding model from previous response" do
    # Create initial response with a specific model
    initial_response =
      Responses.create!(
        input: "Say hello",
        model: "gpt-4o"
      )

    # Create follow-up with a different model
    follow_up_response =
      Responses.create!(
        initial_response,
        input: "Say goodbye",
        model: "gpt-4.1-nano"
      )

    # The follow-up should use the explicitly provided model
    assert follow_up_response.body["model"] =~ ~r/gpt-4.1-nano/
  end

  @tag :api
  test "create/1 with manual previous_response_id uses default model when no model specified" do
    # Create initial response with a specific model
    initial_response =
      Responses.create!(
        input: "Say hello",
        model: "gpt-4o-mini"
      )

    # Verify the initial response uses the specified model
    assert initial_response.body["model"] =~ ~r/gpt-4o-mini/

    # When using manual previous_response_id without specifying a model,
    # the default model is used (NOT inherited from previous response)
    follow_up_response =
      Responses.create!(
        input: "Say goodbye",
        previous_response_id: initial_response.body["id"]
      )

    # The default model is used since we didn't specify one
    # Default model is gpt-4.1-mini, not gpt-4o-mini
    assert follow_up_response.body["model"] =~ ~r/gpt-4\.1-mini/
    refute follow_up_response.body["model"] =~ ~r/gpt-4o-mini/

    # Verify it maintains context from previous response
    assert follow_up_response.body["previous_response_id"] == initial_response.body["id"]
  end

  @tag :api
  test "create/1 with manual previous_response_id and explicit model uses the specified model" do
    # Create initial response with a specific model
    initial_response =
      Responses.create!(
        input: "Say hello",
        model: "gpt-4o-mini"
      )

    # Create follow-up using manual previous_response_id with explicit model
    follow_up_response =
      Responses.create!(
        input: "Say goodbye",
        previous_response_id: initial_response.body["id"],
        model: "gpt-4o"
      )

    # The follow-up should use the explicitly provided model
    assert follow_up_response.body["model"] =~ ~r/gpt-4o/
    # And not the model from the previous response
    refute follow_up_response.body["model"] =~ ~r/gpt-4o-mini/
  end

  describe "create with schema option" do
    @tag :api
    test "create with schema option generates structured response with map schema" do
      response =
        Responses.create!(
          input: "Generate user data for John Doe with email john@example.com",
          schema: %{
            name: :string,
            email: {:string, format: "email"},
            age: :number
          }
        )

      assert response.parsed != nil
      assert response.parse_error == nil
      assert is_map(response.parsed)
      assert Map.has_key?(response.parsed, "name")
      assert Map.has_key?(response.parsed, "email")
      assert response.parsed["email"] =~ "@"
    end

    @tag :api
    test "create with schema option generates structured response with keyword list schema" do
      response =
        Responses.create!(
          input: "Generate user data for Jane Smith with username @jane123",
          schema: [
            username: {:string, pattern: "^@[a-zA-Z0-9_]+$"},
            name: :string,
            active: :boolean
          ]
        )

      assert response.parsed != nil
      assert response.parse_error == nil
      assert is_map(response.parsed)
      assert Map.has_key?(response.parsed, "username")
      assert Map.has_key?(response.parsed, "name")
      assert Map.has_key?(response.parsed, "active")
      assert response.parsed["username"] =~ ~r/^@/
      assert is_boolean(response.parsed["active"])
    end

    @tag :api
    test "create with complex nested schema" do
      response =
        Responses.create!(
          input: "Generate a user profile with contact information",
          schema: %{
            user: %{
              name: :string,
              contact: %{
                email: {:string, format: "email"},
                phone: :string
              }
            },
            metadata: %{
              created_at: :string,
              version: :number
            }
          }
        )

      assert response.parsed != nil
      assert response.parse_error == nil
      assert Map.has_key?(response.parsed, "user")
      assert Map.has_key?(response.parsed, "metadata")
      assert Map.has_key?(response.parsed["user"], "contact")
      assert Map.has_key?(response.parsed["user"]["contact"], "email")
    end

    @tag :api
    test "create with array schema" do
      response =
        Responses.create!(
          input: "Generate a list of 3 users",
          schema: %{
            users:
              {:array,
               %{
                 name: :string,
                 age: :number
               }},
            total_count: :number
          }
        )

      assert response.parsed != nil
      assert response.parse_error == nil
      assert Map.has_key?(response.parsed, "users")
      assert is_list(response.parsed["users"])
      assert length(response.parsed["users"]) >= 1

      first_user = List.first(response.parsed["users"])
      assert Map.has_key?(first_user, "name")
      assert Map.has_key?(first_user, "age")
    end

    @tag :api
    test "response without schema has no parsed field set" do
      response = Responses.create!(input: "Just return some text")

      # For non-structured responses, parsed should not be set
      # extract_json detects it's not a structured response and sets parse_error
      assert response.parsed == nil
      assert response.parse_error == nil
      assert response.text != nil
    end
  end

  describe "run/2 with function calling" do
    @tag :api
    test "run/2 executes functions and returns all responses" do
      # Define mock functions
      functions = %{
        "get_current_time" => fn %{} ->
          "2024-01-15 10:30:00 UTC"
        end,
        "add_numbers" => fn %{"a" => a, "b" => b} ->
          "The sum of #{a} and #{b} is #{a + b}"
        end
      }

      # Define function tools
      time_tool =
        Responses.Schema.build_function(
          "get_current_time",
          "Get the current time",
          %{}
        )

      add_tool =
        Responses.Schema.build_function(
          "add_numbers",
          "Add two numbers together",
          %{a: :number, b: :number}
        )

      # Run the conversation
      responses =
        Responses.run(
          [
            input: "What time is it and what is 15 + 27?",
            tools: [time_tool, add_tool]
          ],
          functions
        )

      # Should have at least 2 responses (initial + final)
      assert length(responses) >= 2

      # First response should have function calls
      first_response = List.first(responses)
      assert first_response.function_calls != nil
      assert length(first_response.function_calls) > 0

      # Last response should have no function calls
      last_response = List.last(responses)
      assert last_response.function_calls == nil || last_response.function_calls == []

      # Final text should contain the results
      assert last_response.text =~ "42"
      assert last_response.text =~ "10:30"
    end

    @tag :api
    test "run/2 handles missing functions gracefully" do
      # Define only one function
      functions = %{
        "get_weather" => fn %{"location" => location} ->
          "The weather in #{location} is sunny"
        end
      }

      # Define tools including one that doesn't have an implementation
      weather_tool =
        Responses.Schema.build_function(
          "get_weather",
          "Get weather for a location",
          %{location: :string}
        )

      time_tool =
        Responses.Schema.build_function(
          "get_time",
          "Get current time",
          %{}
        )

      responses =
        Responses.run(
          [
            input: "What's the weather in Paris and what time is it?",
            tools: [weather_tool, time_tool]
          ],
          functions
        )

      # Should complete successfully
      assert is_list(responses)
      assert length(responses) >= 2

      # Final response should mention the error or handle it gracefully
      last_response = List.last(responses)
      assert last_response.text != nil
    end

    @tag :api
    test "run/2 works with keyword list of functions" do
      functions = [
        get_weather: fn %{"location" => location} ->
          "Weather in #{location}: 20°C"
        end
      ]

      weather_tool =
        Responses.Schema.build_function(
          "get_weather",
          "Get weather",
          %{location: :string}
        )

      responses =
        Responses.run(
          [
            input: "What's the weather in London?",
            tools: [weather_tool]
          ],
          functions
        )

      assert is_list(responses)
      last_response = List.last(responses)
      assert last_response.text =~ "20°C"
    end

    @tag :api
    test "run!/2 raises on error" do
      # Test with invalid input that would cause an error
      assert_raise RuntimeError, fn ->
        Responses.run!(
          [input: "test", model: "invalid-model"],
          %{}
        )
      end
    end

    @tag :api
    test "run/2 handles function exceptions" do
      functions = %{
        "divide" => fn %{"a" => a, "b" => b} ->
          if b == 0 do
            raise "Division by zero"
          else
            "#{a} / #{b} = #{a / b}"
          end
        end
      }

      divide_tool =
        Responses.Schema.build_function(
          "divide",
          "Divide two numbers",
          %{a: :number, b: :number}
        )

      responses =
        Responses.run(
          [
            input: "What is 10 divided by 5?",
            tools: [divide_tool]
          ],
          functions
        )

      # Should handle normal division
      assert is_list(responses)
      assert length(responses) >= 2

      # Test division by zero separately
      zero_responses =
        Responses.run(
          [
            input: "What is 10 divided by 0?",
            tools: [divide_tool]
          ],
          functions
        )

      # Should handle the exception gracefully
      assert is_list(zero_responses)
    end

    @tag :api
    test "run/2 with no function calls returns single response" do
      functions = %{
        "unused_function" => fn _ -> "This won't be called" end
      }

      responses =
        Responses.run(
          [input: "Just tell me a joke about programming"],
          functions
        )

      # Should only have one response since no functions were called
      assert length(responses) == 1
      assert List.first(responses).text != nil
    end
  end
end
