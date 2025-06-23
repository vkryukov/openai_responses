defmodule OpenAI.Responses.CallFunctionsTest do
  use ExUnit.Case
  alias OpenAI.Responses

  describe "call_functions/2" do
    test "executes functions and formats outputs" do
      function_calls = [
        %{name: "add", call_id: "call_123", arguments: %{"a" => 5, "b" => 3}},
        %{name: "multiply", call_id: "call_456", arguments: %{"x" => 4, "y" => 7}}
      ]

      functions = %{
        "add" => fn %{"a" => a, "b" => b} -> a + b end,
        "multiply" => fn %{"x" => x, "y" => y} -> x * y end
      }

      outputs = Responses.call_functions(function_calls, functions)

      assert [
               %{type: "function_call_output", call_id: "call_123", output: 8},
               %{type: "function_call_output", call_id: "call_456", output: 28}
             ] = outputs
    end

    test "handles missing functions gracefully" do
      function_calls = [
        %{name: "missing_function", call_id: "call_789", arguments: %{}}
      ]

      functions = %{}

      outputs = Responses.call_functions(function_calls, functions)

      assert [
               %{
                 type: "function_call_output",
                 call_id: "call_789",
                 output: "Error: Function 'missing_function' not found"
               }
             ] = outputs
    end

    test "handles function errors gracefully" do
      function_calls = [
        %{name: "failing_function", call_id: "call_999", arguments: %{}}
      ]

      functions = %{
        "failing_function" => fn _ -> raise "Something went wrong!" end
      }

      outputs = Responses.call_functions(function_calls, functions)

      assert [
               %{
                 type: "function_call_output",
                 call_id: "call_999",
                 output: "Error calling function 'failing_function': Something went wrong!"
               }
             ] = outputs
    end

    test "works with keyword list of functions" do
      function_calls = [
        %{name: "greet", call_id: "call_111", arguments: %{"name" => "Alice"}}
      ]

      functions = [
        greet: fn %{"name" => name} -> "Hello, #{name}!" end
      ]

      outputs = Responses.call_functions(function_calls, functions)

      assert [
               %{
                 type: "function_call_output",
                 call_id: "call_111",
                 output: "Hello, Alice!"
               }
             ] = outputs
    end

    test "returns various data types without conversion" do
      function_calls = [
        %{name: "get_map", call_id: "call_222", arguments: %{}},
        %{name: "get_list", call_id: "call_333", arguments: %{}},
        %{name: "get_number", call_id: "call_444", arguments: %{}}
      ]

      functions = %{
        "get_map" => fn _ -> %{status: "ok", value: 42} end,
        "get_list" => fn _ -> ["item1", "item2", 3] end,
        "get_number" => fn _ -> 3.14159 end
      }

      outputs = Responses.call_functions(function_calls, functions)

      assert [
               %{
                 type: "function_call_output",
                 call_id: "call_222",
                 output: %{status: "ok", value: 42}
               },
               %{
                 type: "function_call_output",
                 call_id: "call_333",
                 output: ["item1", "item2", 3]
               },
               %{
                 type: "function_call_output",
                 call_id: "call_444",
                 output: 3.14159
               }
             ] = outputs
    end
  end
end
