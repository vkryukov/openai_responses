defmodule OpenAI.Responses.StructuredOutputTest do
  use ExUnit.Case

  alias OpenAI.Responses
  alias OpenAI.Responses.Schema

  @tag :integration
  # Set a longer timeout for API calls
  @tag timeout: 30000
  test "structured output with parse function" do
    # Define a simple schema
    calendar_event_schema =
      Schema.object(%{
        name: :string,
        date: :string,
        participants: {:array, :string}
      })

    # Create a prompt
    prompt = "Alice and Bob are going to a science fair on Friday."

    # Test the parse function
    opts = [
      # Or another capable model
      model: "gpt-4o",
      input: prompt,
      schema_name: "event"
      # Add other necessary opts like instructions if parse/2 requires them implicitly
      # instructions: "Extract event details as per the 'event' schema."
    ]

    case Responses.parse(calendar_event_schema, opts) do
      {:ok, response} ->
        parsed_data = response.parsed
        # Validate the parsed data structure
        assert is_map(parsed_data), "Parsed data should be a map"
        assert Map.has_key?(parsed_data, "name"), "Parsed data should have a name key"
        assert Map.has_key?(parsed_data, "date"), "Parsed data should have a date key"

        assert Map.has_key?(parsed_data, "participants"),
               "Parsed data should have a participants key"

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
end
