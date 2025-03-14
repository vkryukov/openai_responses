defmodule OpenAI.Responses.Helpers do
  @moduledoc """
  Helper functions for working with OpenAI Responses.
  
  This module provides utility functions for common tasks when working
  with the OpenAI Responses API, including:
  
  - Extracting text and data from responses
  - Creating structured input messages
  - Handling response status and errors
  
  See the individual function documentation for usage examples.
  """
  
  alias OpenAI.Responses.Helpers.InputHelpers

  @doc """
  Creates a structured input message with text and optional images.
  
  Uses the InputHelpers module to create a properly formatted input message
  for the OpenAI Responses API. See `OpenAI.Responses.Helpers.InputHelpers.create_input_message/3`
  for full documentation.
  
  ## Examples
  
      # Simple text with one image URL
      iex> input_message = OpenAI.Responses.Helpers.create_input_message("What is in this image?", "https://example.com/image.jpg")
      iex> {:ok, response} = OpenAI.Responses.create("gpt-4o", [input_message])
      
      # With a local file
      iex> input_message = OpenAI.Responses.Helpers.create_input_message("Describe this", "/path/to/image.jpg")
      
      # With multiple images and high detail
      iex> input_message = OpenAI.Responses.Helpers.create_input_message(
      ...>   "Compare these", 
      ...>   ["image1.jpg", "image2.jpg"],
      ...>   detail: "high"
      ...> )
  """
  defdelegate create_input_message(text, images \\ nil, opts \\ []), to: InputHelpers
  
  @doc """
  Extracts the text output from a response.
  
  Returns the main text content from the model's response.
  
  ## Examples
  
      iex> {:ok, response} = OpenAI.Responses.create("gpt-4o", "Hello")
      iex> OpenAI.Responses.Helpers.output_text(response)
      "Hello! How can I assist you today?"
  """
  @spec output_text(map()) :: String.t()
  def output_text(response) do
    # Implementation will depend on the actual response structure
    # This is a placeholder - real implementation would extract text from the response
    "Placeholder implementation"
  end
  
  @doc """
  Gets token usage information from a response.
  
  Returns a map with token usage statistics.
  
  ## Examples
  
      iex> {:ok, response} = OpenAI.Responses.create("gpt-4o", "Hello")
      iex> OpenAI.Responses.Helpers.token_usage(response)
      %{prompt_tokens: 5, completion_tokens: 15, total_tokens: 20}
  """
  @spec token_usage(map()) :: map()
  def token_usage(response) do
    # Implementation will depend on the actual response structure
    # This is a placeholder - real implementation would extract token usage
    %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
  end
  
  @doc """
  Gets the status of a response.
  
  Returns the status of the response, such as "completed" or "error".
  
  ## Examples
  
      iex> {:ok, response} = OpenAI.Responses.create("gpt-4o", "Hello")
      iex> OpenAI.Responses.Helpers.status(response)
      "completed"
  """
  @spec status(map()) :: String.t()
  def status(response) do
    # Implementation will depend on the actual response structure
    # This is a placeholder - real implementation would extract status
    "completed"
  end
  
  @doc """
  Checks if a response contains a refusal.
  
  Returns true if the model refused to respond to the prompt.
  
  ## Examples
  
      iex> {:ok, response} = OpenAI.Responses.create("gpt-4o", "Generate harmful content")
      iex> OpenAI.Responses.Helpers.has_refusal?(response)
      true
  """
  @spec has_refusal?(map()) :: boolean()
  def has_refusal?(response) do
    # Implementation will depend on the actual response structure
    # This is a placeholder - real implementation would check for refusal
    false
  end
  
  @doc """
  Gets the refusal message from a response, if present.
  
  Returns the refusal message string or nil if there's no refusal.
  
  ## Examples
  
      iex> {:ok, response} = OpenAI.Responses.create("gpt-4o", "Generate harmful content")
      iex> OpenAI.Responses.Helpers.refusal_message(response)
      "I cannot generate content that could be harmful."
  """
  @spec refusal_message(map()) :: String.t() | nil
  def refusal_message(response) do
    # Implementation will depend on the actual response structure
    # This is a placeholder - real implementation would extract refusal message
    nil
  end
end