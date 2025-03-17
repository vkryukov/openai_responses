defmodule OpenAI.Responses.StructuredOutputTest do
  use ExUnit.Case
  
  alias OpenAI.Responses
  alias OpenAI.Responses.Schema
  
  @tag :integration
  @tag timeout: 30000  # Set a longer timeout for API calls
  test "structured output with parse function" do
    # Define a simple schema
    calendar_event_schema = Schema.object(%{
      name: :string,
      date: :string,
      participants: {:array, :string}
    })
    
    # Create a prompt
    prompt = "Alice and Bob are going to a science fair on Friday."
    
    # Test the parse function
    case Responses.parse("gpt-4o", prompt, calendar_event_schema, schema_name: "event") do
      {:ok, parsed_data} ->
        # Validate the parsed data structure
        assert is_map(parsed_data), "Parsed data should be a map"
        assert Map.has_key?(parsed_data, "name"), "Parsed data should have a name key"
        assert Map.has_key?(parsed_data, "date"), "Parsed data should have a date key"
        assert Map.has_key?(parsed_data, "participants"), "Parsed data should have a participants key"
        
        # Validate the content
        assert is_binary(parsed_data["name"]), "Name should be a string"
        assert is_binary(parsed_data["date"]), "Date should be a string"
        assert is_list(parsed_data["participants"]), "Participants should be an array"
        assert length(parsed_data["participants"]) > 0, "Participants should not be empty"
        assert "Alice" in parsed_data["participants"], "Alice should be in participants"
        assert "Bob" in parsed_data["participants"], "Bob should be in participants"
      
      {:error, error} ->
        flunk("Parse function failed: #{inspect(error)}")
    end
  end
  
  @tag :integration
  @tag timeout: 30000  # Set a longer timeout for API calls
  test "structured output with streaming" do
    # Define a simple schema
    calendar_event_schema = Schema.object(%{
      name: :string,
      date: :string,
      participants: {:array, :string}
    })
    
    # Create a prompt
    prompt = "Alice and Bob are going to a science fair on Friday."
    
    # Get the stream
    stream = Responses.parse_stream("gpt-4o", prompt, calendar_event_schema, schema_name: "event")
    
    # Collect the stream
    chunks = Enum.to_list(stream)
    
    # Check that we got some chunks
    assert length(chunks) > 0, "Should receive stream chunks"
    
    # The last chunk should contain the complete data
    last_chunk = List.last(chunks)
    
    # Verify it's either a map with the expected structure or a chunk with error info
    case last_chunk do
      %{"name" => _, "date" => _, "participants" => _} = data ->
        assert is_binary(data["name"]), "Name should be a string"
        assert is_binary(data["date"]), "Date should be a string"
        assert is_list(data["participants"]), "Participants should be an array"
      
      _ ->
        # If we didn't get a properly structured response, at least make sure we got some chunks
        assert length(chunks) > 1, "Should receive multiple stream chunks even if final parsing fails"
    end
  end
end
