defmodule OpenAI.Responses.Helpers do
  @moduledoc """
  Helper functions for working with OpenAI Responses.
  
  This module provides utility functions for common tasks when working
  with the OpenAI Responses API, including:
  
  - Extracting text and data from responses
  - Creating structured messages with images
  - Handling response status and errors
  
  See the individual function documentation for usage examples.
  """
  
  alias OpenAI.Responses.Helpers.ImageHelpers
  
  @doc """
  Creates a structured message with text and optional images.

  Uses the ImageHelpers module to create a properly formatted message
  with text and images for the OpenAI Responses API. See `OpenAI.Responses.Helpers.ImageHelpers.create_message_with_images/3`
  for full documentation.

  ## Examples

      # Simple text with one image URL
      iex> input_message = OpenAI.Responses.Helpers.create_message_with_images("What is in this image?", "https://example.com/image.jpg")
      iex> {:ok, response} = OpenAI.Responses.create("gpt-4o", [input_message])
      
      # With a local file
      iex> input_message = OpenAI.Responses.Helpers.create_message_with_images("Describe this", "/path/to/image.jpg")
      
      # With multiple images and high detail
      iex> input_message = OpenAI.Responses.Helpers.create_message_with_images(
      ...>   "Compare these", 
      ...>   ["image1.jpg", "image2.jpg"],
      ...>   detail: "high"
      ...> )
  """
  defdelegate create_message_with_images(text, images \\ nil, opts \\ []), to: ImageHelpers
  
  @doc """
  Extracts the output text from a response.
  
  This function navigates the response structure to find and return the generated text.
  If the response contains multiple outputs or messages, it concatenates them with newlines.
  
  ## Parameters
  
    * `response` - The response from OpenAI.Responses.create/3
    
  ## Returns
  
    * The extracted text as a string
    * An empty string if no text output is found
    
  ## Examples
  
      {:ok, response} = OpenAI.Responses.create("gpt-4o", "Write a haiku about programming")
      text = OpenAI.Responses.Helpers.output_text(response)
      # => "Fingers tap keyboard\nLogic blooms in silent code\nBugs hide in plain sight"
  """
  @spec output_text(map()) :: String.t()
  def output_text(response) do
    case response do
      %{"output" => output} when is_list(output) ->
        output
        |> Enum.map(&extract_text_from_item/1)
        |> Enum.filter(&(&1 != ""))
        |> Enum.join("\n")
      _ -> ""
    end
  end
  
  @doc """
  Gets token usage information from a response.
  
  ## Parameters
  
    * `response` - The response from OpenAI.Responses.create/3
    
  ## Returns
  
    * A map with token usage information
    * nil if no usage information is found
    
  ## Examples
  
      {:ok, response} = OpenAI.Responses.create("gpt-4o", "Write a haiku about programming")
      usage = OpenAI.Responses.Helpers.token_usage(response)
      # => %{"input_tokens" => 8, "output_tokens" => 17, "total_tokens" => 25}
  """
  @spec token_usage(map()) :: map() | nil
  def token_usage(response) do
    Map.get(response, "usage")
  end
  
  @doc """
  Extracts the status from a response.
  
  ## Parameters
  
    * `response` - The response from OpenAI.Responses.create/3
    
  ## Returns
  
    * The status as a string (e.g., "completed", "in_progress")
    * nil if no status is found
  """
  @spec status(map()) :: String.t() | nil
  def status(response) do
    Map.get(response, "status")
  end
  
  @doc """
  Checks if a response contains a refusal.
  
  ## Parameters
  
    * `response` - The response from OpenAI.Responses.create/3
    
  ## Returns
  
    * true if the response contains a refusal, false otherwise
  """
  @spec has_refusal?(map()) :: boolean()
  def has_refusal?(response) do
    case response do
      %{"output" => output} when is_list(output) ->
        Enum.any?(output, fn item ->
          case item do
            %{"content" => content} when is_list(content) ->
              Enum.any?(content, &match?(%{"type" => "refusal"}, &1))
            _ -> false
          end
        end)
      _ -> false
    end
  end
  
  @doc """
  Gets the refusal message if one exists.
  
  ## Parameters
  
    * `response` - The response from OpenAI.Responses.create/3
    
  ## Returns
  
    * The refusal message as a string
    * nil if no refusal is found
  """
  @spec refusal_message(map()) :: String.t() | nil
  def refusal_message(response) do
    case response do
      %{"output" => output} when is_list(output) ->
        Enum.find_value(output, fn item ->
          case item do
            %{"content" => content} when is_list(content) ->
              Enum.find_value(content, fn
                %{"type" => "refusal", "refusal" => refusal} -> refusal
                _ -> nil
              end)
            _ -> nil
          end
        end)
      _ -> nil
    end
  end
  
  # Private helpers
  
  defp extract_text_from_item(item) do
    case item do
      %{"type" => "message", "content" => content} when is_list(content) ->
        content
        |> Enum.map(&extract_text_content/1)
        |> Enum.filter(&(&1 != ""))
        |> Enum.join("\n")
      _ -> ""
    end
  end
  
  defp extract_text_content(content) do
    case content do
      %{"type" => "output_text", "text" => text} when is_binary(text) -> text
      _ -> ""
    end
  end
end