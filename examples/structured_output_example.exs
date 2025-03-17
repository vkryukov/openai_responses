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
    _calendar_event_schema = Schema.object(%{
      name: :string,
      date: :string,
      participants: {:array, :string}
    })
    
    # Create a prompt
    prompt = "Alice and Bob are going to a science fair on Friday."
    
    IO.puts("Prompt: #{prompt}\n")
    IO.puts("Schema: Calendar event with name, date, and participants\n")
    
    # This would make an actual API call if uncommented
    # {:ok, event} = Responses.parse(
    #   "gpt-4o", 
    #   prompt, 
    #   calendar_event_schema,
    #   schema_name: "event"
    # )
    
    # For demonstration purposes, we'll use a mock response
    event = %{
      "name" => "Science Fair",
      "date" => "Friday",
      "participants" => ["Alice", "Bob"]
    }
    
    # Display the result
    IO.puts("Result:")
    IO.puts("  Event: #{event["name"]} on #{event["date"]}")
    IO.puts("  Participants: #{Enum.join(event["participants"], ", ")}")
  end
  
  def math_reasoning_example do
    IO.puts("\n=== Example 2: Math Reasoning ===\n")
    
    # Define a schema for math reasoning with steps
    _math_reasoning_schema = Schema.object(%{
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
    
    # This would make an actual API call if uncommented
    # {:ok, reasoning} = Responses.parse(
    #   "gpt-4o", 
    #   prompt, 
    #   math_reasoning_schema,
    #   schema_name: "math_reasoning"
    # )
    
    # For demonstration purposes, we'll use a mock response
    reasoning = %{
      "steps" => [
        %{
          "explanation" => "First, I'll isolate the terms with x on one side of the equation.",
          "output" => "8x = -23 - 7"
        },
        %{
          "explanation" => "Now I'll simplify the right side.",
          "output" => "8x = -30"
        },
        %{
          "explanation" => "Finally, I'll divide both sides by 8 to solve for x.",
          "output" => "x = -30 / 8 = -3.75"
        }
      ],
      "final_answer" => "x = -3.75"
    }
    
    # Display the result
    IO.puts("Result:")
    IO.puts("  Steps:")
    Enum.with_index(reasoning["steps"], 1) |> Enum.each(fn {step, index} ->
      IO.puts("    Step #{index}:")
      IO.puts("      Explanation: #{step["explanation"]}")
      IO.puts("      Output: #{step["output"]}")
    end)
    IO.puts("  Final Answer: #{reasoning["final_answer"]}")
  end
  
  def content_moderation_example do
    IO.puts("\n=== Example 3: Content Moderation ===\n")
    
    # Define a schema for content moderation
    _moderation_schema = Schema.object(%{
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
    
    # This would make an actual API call if uncommented
    # {:ok, moderation} = Responses.parse(
    #   "gpt-4o", 
    #   prompt, 
    #   moderation_schema,
    #   schema_name: "content_moderation"
    # )
    
    # For demonstration purposes, we'll use a mock response
    moderation = %{
      "is_violating" => false,
      "category" => nil,
      "explanation_if_violating" => nil
    }
    
    # Display the result
    IO.puts("Result:")
    IO.puts("  Is Violating: #{moderation["is_violating"]}")
    IO.puts("  Category: #{moderation["category"] || "N/A"}")
    IO.puts("  Explanation: #{moderation["explanation_if_violating"] || "N/A"}")
  end
end

# Run the examples
StructuredOutputExample.run()
