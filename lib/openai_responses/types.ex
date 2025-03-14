defmodule OpenAI.Responses.Types do
  @moduledoc """
  Type definitions and structs for the OpenAI Responses API.
  
  This module provides functions for converting API responses into
  structured Elixir representations.
  """
  
  @doc """
  Converts a response map from the API into a structured response.
  
  ## Parameters
  
    * `attrs` - The raw response map from the API
  
  ## Returns
  
    * A structured response map
  """
  @spec response(map()) :: map()
  def response(attrs) do
    # We're just passing through the raw response for now,
    # could transform into a struct in the future if beneficial
    attrs
  end
  
  @doc """
  Creates a structured message from API attributes.
  
  ## Parameters
  
    * `attrs` - The raw message map from the API
  
  ## Returns
  
    * A structured message map
  """
  @spec message(map()) :: map()
  def message(attrs) do
    attrs
  end
  
  @doc """
  Creates a function call struct from API attributes.
  
  ## Parameters
  
    * `attrs` - The raw function call map from the API
  
  ## Returns
  
    * A structured function call map
  """
  @spec function_call(map()) :: map()
  def function_call(attrs) do
    attrs
  end
end