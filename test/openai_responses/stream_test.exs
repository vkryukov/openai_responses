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

      # Simulate a stream from the list of events
      simulated_stream = Stream.map(stream_events, & &1)

      result = OpenAI.Responses.Stream.text_deltas(simulated_stream) |> Enum.to_list()

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

      simulated_stream = Stream.map(stream_events, & &1)
      assert OpenAI.Responses.Stream.text_deltas(simulated_stream) |> Enum.to_list() == []
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

      simulated_stream = Stream.map(stream_events, & &1)

      result = OpenAI.Responses.Stream.collect(simulated_stream)

      expected_response = %{
        "id" => "res_123",
        "model" => "gpt-test",
        "status" => "completed",
        "output" => [
          %{
            "type" => "message",
            "content" => [%{"type" => "output_text", "text" => "Final text."}]
          },
          %{
            "type" => "tool_code",
            "language" => "elixir"
          }
        ],
        "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
      }

      assert result == expected_response
    end

    test "collect handles empty stream" do
      assert OpenAI.Responses.Stream.collect([]) == %{}
    end

    test "collect ignores irrelevant events" do
      stream_events = [
        # Ignored by collect
        %{"type" => "response.output_text.delta", "delta" => "abc"},
        # Ignored by collect
        %{"type" => "some_other_event"}
      ]

      simulated_stream = Stream.map(stream_events, & &1)
      assert OpenAI.Responses.Stream.collect(simulated_stream) == %{}
    end

    # Test legacy collect with map input
    test "legacy collect/1 works with map input" do
      stream_events = [
        %{"type" => "response.created", "response" => %{"id" => "res_456"}},
        %{"type" => "response.completed", "response" => %{"status" => "done"}}
      ]

      simulated_stream = Stream.map(stream_events, & &1)
      handler = %{stream: simulated_stream}

      result = OpenAI.Responses.Stream.collect(handler)
      expected_response = %{"id" => "res_456", "status" => "done"}
      assert result == expected_response
    end
  end

  # Add tests for legacy new/2 and text_chunks/1 if desired,
  # though they mainly delegate or are simple wrappers now.

  describe "legacy functions" do
    test "new/2 creates a handler map" do
      stream = Stream.map([1, 2], & &1)
      handler = OpenAI.Responses.Stream.new(stream, foo: :bar)
      assert handler == %{stream: stream, options: %{foo: :bar}}
    end

    test "text_chunks/1 delegates to text_deltas/1" do
      # This test implicitly covers the delegation logic
      stream_events = [%{"type" => "response.output_text.delta", "delta" => "Test"}]
      simulated_stream = Stream.map(stream_events, & &1)
      handler = %{stream: simulated_stream}

      result = OpenAI.Responses.Stream.text_chunks(handler) |> Enum.to_list()
      assert result == ["Test"]
    end
  end
end
