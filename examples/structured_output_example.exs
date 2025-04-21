#!/usr/bin/env elixir

# Example script demonstrating the structured output API

# Add the lib directory to the code path
Code.prepend_path(Path.join([File.cwd!(), "lib"]))

defmodule StructuredOutputExample do
  @moduledoc """
  Examples of using the structured output API.
  """

  alias OpenAI.Responses
  alias OpenAI.Responses.Schema

  def run do
    IO.puts("OpenAI Structured Output Examples\n")

    # Example 1: Simple calendar event
    calendar_event_example()

    # Example 2: Math reasoning with steps
    math_reasoning_example()

    # Example 3: Content moderation
    content_moderation_example()
  end

  def calendar_event_example do
    IO.puts("\n=== Example 1: Calendar Event ===\n")

    # Define a schema for a calendar event
    calendar_event_schema = Schema.object(%{
      name: :string,
      date: :string,
      participants: {:array, :string}
    })

    # Create a prompt
    prompt = "Alice and Bob are going to a science fair on Friday."

    IO.puts("Prompt: #{prompt}\n")
    IO.puts("Schema: Calendar event with name, date, and participants\n")

    # Make an actual API call
    {:ok, result} = Responses.parse(
      calendar_event_schema,
      model: "gpt-4.1-mini",
      input: prompt,
      schema_name: "event"
    )

    # Display the result
    IO.puts("Result:")
    IO.puts("  Event: #{result.parsed["name"]} on #{result.parsed["date"]}")
    IO.puts("  Participants: #{Enum.join(result.parsed["participants"], ", ")}")
    IO.inspect(result.token_usage, label: "Token Usage")
  end

  def math_reasoning_example do
    IO.puts("\n=== Example 2: Math Reasoning ===\n")

    # Define a schema for math reasoning with steps
    math_reasoning_schema = Schema.object(%{
      steps: {:array, Schema.object(%{
        explanation: :string,
        output: :string
      })},
      final_answer: :string
    })

    # Create a prompt
    prompt = "Solve 8x + 7 = -23"

    IO.puts("Prompt: #{prompt}\n")
    IO.puts("Schema: Math reasoning with steps and final answer\n")

    # Make an actual API call
    {:ok, result} = Responses.parse(
      math_reasoning_schema,
      model: "gpt-4.1-mini",
      input: prompt,
      schema_name: "math_reasoning"
    )

    # Display the result
    IO.puts("Result:")
    IO.puts("  Steps:")
    Enum.with_index(result.parsed["steps"], 1) |> Enum.each(fn {step, index} ->
      IO.puts("    Step #{index}:")
      IO.puts("      Explanation: #{step["explanation"]}")
      IO.puts("      Output: #{step["output"]}")
    end)
    IO.puts("  Final Answer: #{result.parsed["final_answer"]}")
    IO.inspect(result.token_usage, label: "Token Usage")
  end

  def content_moderation_example do
    IO.puts("\n=== Example 3: Content Moderation ===\n")

    # Define a schema for content moderation
    moderation_schema = Schema.object(%{
      is_violating: :boolean,
      category: Schema.nullable(
        Schema.string(
          enum: ["violence", "sexual", "self_harm"]
        )
      ),
      explanation_if_violating: Schema.nullable(:string)
    })

    # Create a prompt
    prompt = "Check if this content violates guidelines: 'I love programming in Elixir!'"

    IO.puts("Prompt: #{prompt}\n")
    IO.puts("Schema: Content moderation with violation check\n")

    # Make an actual API call
    {:ok, result} = Responses.parse(
      moderation_schema,
      model: "gpt-4.1-mini",
      input: prompt,
      schema_name: "content_moderation"
    )

    # Display the result
    IO.puts("Result:")
    IO.puts("  Is Violating: #{result.parsed["is_violating"]}")
    IO.puts("  Category: #{result.parsed["category"] || "N/A"}")
    IO.puts("  Explanation: #{result.parsed["explanation_if_violating"] || "N/A"}")
    IO.inspect(result.token_usage, label: "Token Usage")
  end
end

# Run the examples
StructuredOutputExample.run()
