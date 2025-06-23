defmodule OpenAI.Responses.Error do
  @moduledoc """
  Exception module for OpenAI API errors.

  This module represents errors that can occur when making requests to the OpenAI API.
  It includes standard OpenAI error fields as well as HTTP status codes.

  ## Fields

  * `:message` - Human-readable error description
  * `:code` - OpenAI error code (e.g., "invalid_api_key")
  * `:param` - The parameter that caused the error (if applicable)
  * `:type` - OpenAI error type (e.g., "invalid_request_error")
  * `:status` - HTTP status code from the response

  ## Examples

      iex> error = %OpenAI.Responses.Error{
      ...>   message: "Rate limit exceeded",
      ...>   code: "rate_limit_exceeded",
      ...>   type: "rate_limit_exceeded",
      ...>   status: 429
      ...> }
      iex> OpenAI.Responses.Error.retryable?(error)
      true

  """
  defexception [:message, :code, :param, :type, :status]

  def from_response(%Req.Response{} = response) do
    error = if is_map(response.body), do: response.body["error"], else: nil

    if is_map(error) do
      %__MODULE__{
        message: error["message"],
        code: error["code"],
        param: error["param"],
        type: error["type"],
        status: response.status
      }
    else
      %__MODULE__{
        message: "Unknown error: #{inspect(response.body)}",
        status: response.status
      }
    end
  end

  @doc """
  Determines if an error is retryable.

  Returns `true` if the error is due to temporary server issues that may resolve
  with retry attempts, such as rate limits, internal server errors, or network
  timeouts. Returns `false` for client errors like malformed requests that will
  not succeed on retry.

  ## Retryable conditions

  ### HTTP status codes
  * `429` - Rate limit or quota exceeded
  * `500` - Internal server error
  * `503` - Service overloaded / Slow down

  ### Transport errors
  * `:timeout` - Request timeout
  * `:closed` - Connection closed

  ## Examples

      iex> error = %OpenAI.Responses.Error{status: 429}
      iex> OpenAI.Responses.Error.retryable?(error)
      true

      iex> error = %OpenAI.Responses.Error{status: 400}
      iex> OpenAI.Responses.Error.retryable?(error)
      false

      iex> error = %Req.TransportError{reason: :timeout}
      iex> OpenAI.Responses.Error.retryable?(error)
      true
  """
  def retryable?(%__MODULE__{status: status}) do
    status in [429, 500, 503]
  end

  def retryable?(%Req.TransportError{reason: reason}) do
    reason in [:timeout, :closed]
  end

  def retryable?() do
    false
  end
end
