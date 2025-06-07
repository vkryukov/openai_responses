defmodule OpenAI.Responses.Internal do
  @moduledoc false

  @default_model "gpt-4.1-mini"

  @doc """
  Prepare the payload for API requests.
  Handles schema conversion and sets default model.
  """
  def prepare_payload(options) do
    {schema, options} = Keyword.pop(options, :schema)

    options =
      if schema do
        Keyword.put(options, :text, %{format: OpenAI.Responses.Schema.build_output(schema)})
      else
        options
      end

    options
    |> Keyword.put_new(:model, @default_model)
    |> Map.new()
  end

  @doc """
  Get the API key from application config or environment variable.
  """
  def get_api_key() do
    Application.get_env(:openai_responses, :openai_api_key) || System.fetch_env!("OPENAI_API_KEY")
  end
end
