defmodule OpenAI.Responses.StreamTest do
  use ExUnit.Case, async: true

  alias OpenAI.Responses.Stream

  describe "text_deltas/1" do
    test "extracts text deltas correctly, skipping done/completed text" do
      stream_events = [
        %{"type" => "response.output_text.delta", "delta" => "Hello"},
        %{"type" => "response.output_text.delta", "delta" => " "},
        # This should be skipped as delta covers it
        %{"type" => "response.output_text.done", "text" => "Hello "},
        %{"type" => "response.output_text.delta", "delta" => "world"},
        %{"type" => "response.output_text.delta", "delta" => "!"},
        # This should be skipped
        %{"type" => "response.output_text.done", "text" => "world!"},
        %{"type" => "some_other_event"},
        # This marks completion but text within it shouldn't be extracted by text_deltas
        %{
          "type" => "response.completed",
          "response" => %{"output" => [%{"text" => "Hello world!"}]}
        }
      ]

      # Use the raw list as input
      result_stream = OpenAI.Responses.Stream.text_deltas(stream_events)

      result = Enum.to_list(result_stream)

      assert result == ["Hello", " ", "world", "!"]
    end

    test "handles empty stream" do
      assert OpenAI.Responses.Stream.text_deltas([]) |> Enum.to_list() == []
    end

    test "handles stream with no text deltas" do
      stream_events = [
        %{"type" => "response.created"},
        %{"type" => "response.output_item.added"},
        %{"type" => "response.completed"}
      ]

      # Use the raw list as input
      result_stream = OpenAI.Responses.Stream.text_deltas(stream_events)

      result = Enum.to_list(result_stream)

      assert result == []
    end
  end

  describe "collect/1" do
    test "collects events into a final response map" do
      stream_events = [
        # Initial response creation
        %{
          "type" => "response.created",
          "response" => %{
            "id" => "res_123",
            "model" => "gpt-test",
            "status" => "in_progress"
          }
        },
        # First output item added
        %{
          "type" => "response.output_item.added",
          # Content will be filled later
          "item" => %{"type" => "message", "content" => []},
          "output_index" => 0
        },
        # Text content for the first item
        %{
          "type" => "response.output_text.done",
          "text" => "Final text.",
          "output_index" => 0,
          "content_index" => 0
        },
        # Second output item added
        %{
          "type" => "response.output_item.added",
          # Different type
          "item" => %{"type" => "tool_code", "language" => "elixir"},
          "output_index" => 1
        },
        # Completion event with final usage
        %{
          "type" => "response.completed",
          "response" => %{
            "status" => "completed",
            "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
          }
        }
      ]

      # Use the raw list as input
      result = OpenAI.Responses.Stream.collect(stream_events)

      expected_response = %{
        "status" => "completed",
        "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
      }

      assert result == expected_response
    end

    test "collect handles empty stream" do
      assert OpenAI.Responses.Stream.collect([]) == %{}
    end

    test "collect ignores irrelevant events" do
      stream_events = [
        %{"type" => "response.output_text.delta", "delta" => "abc"},
        %{"type" => "some_other_event"},
        %{"type" => "response.completed", "response" => %{"status" => "completed"}}
      ]

      # Use the raw list as input
      result = OpenAI.Responses.Stream.collect(stream_events)

      assert result == %{"status" => "completed"}
    end

    # Test legacy collect with map input
    test "legacy collect/1 works with map input" do
      stream_events = [
        %{"type" => "response.created", "response" => %{"id" => "res_456"}},
        %{"type" => "response.completed", "response" => %{"status" => "done"}}
      ]

      # Use the raw list as input
      result = OpenAI.Responses.Stream.collect(stream_events)
      expected_response = %{"status" => "done"}
      assert result == expected_response
    end
  end

  # Add tests for legacy new/2 and text_chunks/1 if desired,
  # though they mainly delegate or are simple wrappers now.

  describe "legacy functions" do
    test "new/2 creates a handler map" do
      handlers = %{on_delta: &(&1 <> "."), on_done: & &1}
      result = OpenAI.Responses.Stream.new([1, 2], handlers)
      assert result.stream == [1, 2]
      assert Map.has_key?(result.options, :on_delta)
      assert Map.has_key?(result.options, :on_done)
    end

    test "text_chunks/1 delegates to text_deltas/1" do
      # This test implicitly covers the delegation logic
      stream_events = [%{"type" => "response.output_text.delta", "delta" => "Test"}]

      # Use a map with stream key as input
      result_stream = OpenAI.Responses.Stream.text_chunks(%{stream: stream_events})

      result = Enum.to_list(result_stream)
      assert result == ["Test"]
    end
  end
end
