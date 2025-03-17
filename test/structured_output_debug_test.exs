defmodule OpenAI.Responses.StructuredOutputDebugTest do
  use ExUnit.Case
  
  alias OpenAI.Responses
  alias OpenAI.Responses.Schema
  
  @tag :debug
  @tag timeout: 30000  # Set a longer timeout for API calls
  test "debug structured output response format with new API" do
    # Define a simple schema
    calendar_event_schema = Schema.object(%{
      name: :string,
      date: :string,
      participants: {:array, :string}
    })
    
    # Create a prompt
    prompt = "Alice and Bob are going to a science fair on Friday."
    
    IO.puts("\nPrompt: #{prompt}")
    IO.puts("Schema: Calendar event with name, date, and participants\n")
    
    # First test with direct create to see the raw response
    IO.puts("Testing direct API call with new format...\n")
    
    # Prepare the text format with the schema according to the new API format
    text_format = %{
      format: %{
        type: "json_schema",
        name: "calendar_event",
        schema: calendar_event_schema,
        strict: true
      }
    }
    
    # Add system message
    system_message = "Extract the event information."
    
    # Call create directly
    case Responses.create("gpt-4o", prompt, text: text_format, instructions: system_message) do
      {:ok, raw_response} ->
        IO.puts("=== Raw Response ===\n")
        IO.inspect(raw_response, pretty: true, limit: :infinity)
        
        IO.puts("\n=== Response Keys ===\n")
        IO.inspect(Map.keys(raw_response), label: "Top-level keys")
        
        # Now test our parse function
        IO.puts("\n\nTesting parse function...\n")
        
        case Responses.parse("gpt-4o", prompt, calendar_event_schema, schema_name: "event") do
          {:ok, parsed_data} ->
            IO.puts("=== Parsed Data ===\n")
            IO.inspect(parsed_data, pretty: true, limit: :infinity)
            assert is_map(parsed_data), "Parsed data should be a map"
            assert Map.has_key?(parsed_data, "name"), "Parsed data should have a name key"
            assert Map.has_key?(parsed_data, "date"), "Parsed data should have a date key"
            assert Map.has_key?(parsed_data, "participants"), "Parsed data should have a participants key"
          
          {:error, error} ->
            IO.puts("Error from parse function: #{inspect(error)}")
            flunk("Parse function failed: #{inspect(error)}")
        end
      
      {:error, error} ->
        IO.puts("Error calling API directly: #{inspect(error)}")
        flunk("Direct API call failed: #{inspect(error)}")
    end
  end
end
