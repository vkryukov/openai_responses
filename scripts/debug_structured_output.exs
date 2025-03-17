#!/usr/bin/env elixir

# Debug script for structured outputs
# This script directly calls the OpenAI API and inspects the raw response

# Add the lib directory to the code path
Code.prepend_path(Path.join([File.cwd!(), "lib"]))

defmodule StructuredOutputDebug do
  @moduledoc """
  Debug module for structured outputs
  """
  
  alias OpenAI.Responses
  alias OpenAI.Responses.Schema
  
  def run do
    IO.puts("=== Debugging Structured Output API ===\n")
    
    # Define a simple schema
    calendar_event_schema = Schema.object(%{
      name: :string,
      date: :string,
      participants: {:array, :string}
    })
    
    # Create a prompt
    prompt = "Alice and Bob are going to a science fair on Friday."
    
    IO.puts("Prompt: #{prompt}\n")
    IO.puts("Schema: Calendar event with name, date, and participants\n")
    
    # Prepare the response format with the schema
    response_format = %{
      type: "json_schema",
      schema: calendar_event_schema
    }
    
    # Call create directly to get the raw response
    IO.puts("Calling OpenAI API directly...\n")
    
    case Responses.create("gpt-4o", prompt, response_format: response_format) do
      {:ok, response} ->
        IO.puts("=== Raw Response ===\n")
        IO.inspect(response, pretty: true, limit: :infinity)
        
        IO.puts("\n=== Response Keys ===\n")
        IO.inspect(Map.keys(response), label: "Top-level keys")
        
        if Map.has_key?(response, "content") do
          IO.puts("\n=== Content Structure ===\n")
          IO.inspect(response["content"], label: "Content", pretty: true)
        end
        
        if Map.has_key?(response, "output") do
          IO.puts("\n=== Output Structure ===\n")
          IO.inspect(response["output"], label: "Output", pretty: true)
        end
        
        # Try to extract the structured data manually
        IO.puts("\n=== Manual Extraction Attempts ===\n")
        
        # Attempt 1: Try to find JSON in content
        content_extraction = case response do
          %{"content" => [%{"text" => json_text}]} ->
            try do
              {:ok, Jason.decode!(json_text)}
            rescue
              e -> {:error, "Failed to parse JSON: #{inspect(e)}"}
            end
          
          %{"content" => content} when is_binary(content) ->
            try do
              {:ok, Jason.decode!(content)}
            rescue
              _ -> {:error, "Content is not valid JSON"}
            end
            
          _ -> {:error, "No content found"}
        end
        
        IO.puts("Content extraction attempt: ")
        IO.inspect(content_extraction, pretty: true)
        
        # Attempt 2: Look for parsed data in output
        output_extraction = case response do
          %{"output" => output} when is_list(output) ->
            Enum.find_value(output, {:error, "No parsed data found"}, fn item ->
              case item do
                %{"type" => "message", "content" => content} when is_list(content) ->
                  Enum.find_value(content, nil, fn
                    %{"type" => "parsed", "parsed" => parsed} -> {:ok, parsed}
                    _ -> nil
                  end)
                
                _ -> nil
              end
            end)
            
          _ -> {:error, "No output found"}
        end
        
        IO.puts("\nOutput extraction attempt: ")
        IO.inspect(output_extraction, pretty: true)
        
      {:error, error} ->
        IO.puts("Error calling API: #{inspect(error)}")
    end
  end
end

# Run the debug module
StructuredOutputDebug.run()
