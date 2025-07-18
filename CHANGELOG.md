# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.6.0

### Added
- **Automatic array wrapping for Structured Outputs** - Arrays can now be used at the root level of schema definitions. The library automatically wraps arrays in objects to comply with OpenAI's requirement that the root level must be an object, and unwraps them in the response:
  ```elixir
  Responses.create!(
    input: "list facts about 3 US presidents", 
    schema: {:array, %{
      name: :string,
      birth_year: :integer,
      little_known_facts: {:array, {:string, max_items: 2}}
    }}
  )
  # Returns an array directly, not wrapped in an object
  ```
  - `Schema.build_output/1` detects array schemas and wraps them in an object with an "items" property
  - `Response.extract_json/1` detects wrapped arrays and automatically unwraps them
  - Objects that naturally have an "items" property are not affected

## 0.5.3

### Fixed
- **Duplicate assistant response handling** - Fixed an issue where the OpenAI API sometimes returns multiple nearly identical assistant responses by only taking the first assistant response in `Response.extract_text/1`

## 0.5.2

### Changed
- **Internal refactoring** - Improved input handling to consistently accept both maps and keyword lists with atom or string keys across all functions
- **Documentation** - Added comprehensive documentation for the `:schema` option in `create/1` function, explaining how to use structured output with examples

### Fixed
- Fixed Dialyzer issues
- Fixed Credo warnings for code quality

## 0.5.1

### Added
- **Map support for options** - Multiple functions now accept maps in addition to keyword lists for options, providing more flexibility and consistency with Elixir conventions:
  - `create/1` and `create/2` - Create responses with map or keyword list options
  - `stream/1` - Stream responses using map or keyword list options
  - `run/2` - Run function calling conversations with map or keyword list options
  - `OpenAI.Responses.Stream.stream/1` and `OpenAI.Responses.Stream.stream_with_callback/2` - Stream functions also accept maps
  - Maps with mixed atom and string keys are supported
  - Example: `Responses.create(%{input: "Hello", model: "gpt-4o"})`

## 0.5.0

### Added
- **Union type support via `anyOf`** - `Schema.build_output/1` and `Schema.build_function/3` now support union types through the `anyOf` specification. This allows defining properties that can be one of multiple types:
  - `{:anyOf, [:string, :number]}` - tuple syntax for simple unions
  - `[:anyOf, [:string, :number]]` - list syntax for simple unions
  - Complex unions with objects and nested structures are fully supported
- **LLM usage guide** - Added comprehensive `usage-rules.md` documentation with detailed examples and best practices for using the OpenAI.Responses library with LLM agents
- **Manual function calling with `call_functions/2`** - Added public function to execute function calls from a response and format results for the API. This enables custom workflows where users need to intercept, modify, or add context to function results before continuing the conversation. Function return values are passed through without string conversion, so they must be JSON-encodable (maps, lists, strings, numbers, booleans, nil)
- **Error module with retry support** - Added `OpenAI.Responses.Error` exception module that:
  - Represents OpenAI API errors with fields for message, code, param, type, and HTTP status
  - Provides `retryable?/1` function to determine if errors can be retried
  - Supports both HTTP status codes (429, 500, 503) and Req transport errors (timeout, closed)

### Fixed
- **Model preservation in follow-up responses** - `create/2` now correctly preserves the model from the previous response when creating follow-ups, instead of defaulting to the standard model. The model can still be explicitly overridden when needed

### Changed
- **Package metadata** - Updated `mix.exs` to include additional files in the hex package distribution

## 0.4.2

### Added
- **List format support for Schema definitions** - `Schema.build_output/1` and `Schema.build_function/3` now accept list syntax `[type, options]` in addition to tuple syntax `{type, options}`. This provides more flexibility when defining schemas:
  - `[:string, %{description: "Full name"}]` - list with map options
  - `[:string, [description: "Full name"]]` - list with keyword list options
  - `[:array, :string]` - list format for arrays
  - All formats can be mixed within the same schema definition
- Pricing for o3 pro model

### Changed
- **Cost calculation for unknown models** - When pricing data is not available for a model, `Response.calculate_cost/1` now returns zero costs for all categories instead of `nil`. This provides a consistent cost structure regardless of whether the model has pricing information.
- **Schema internals refactored** - The schema building logic now uses a two-phase approach (normalize then build) making it more maintainable and extensible. This is an internal change that doesn't affect the public API.
- Pricing for o3 model updated to reflect 80% price decrease

## 0.4.1

### Added
- **Support for string tuple syntax in Schema arrays** - `Schema.build_property/1` now accepts `{"array", item_type}` in addition to `{:array, item_type}` for defining array types in schemas
- **Support for string keys in Schema definitions** - `Schema.build_output/1` and `Schema.build_function/3` now accept lists with string keys in addition to keyword lists with atom keys. This enables schemas to be stored in databases or other persistence layers where atoms are converted to strings, and then reused without conversion back to atoms

## 0.4.0

Major refactoring to make the codebase more modular and maintainable, and simplify the API.

### Breaking Changes
- **Removed `:client` option** from `create/1`
- **Removed `Responses.Helpers` module** - cost is now calculated automatically for models with known pricing
- **Removed image helpers** for now until a better API can be designed
- **Removed `delete/2`, `get/2`, and `list_input_items/2`** - use the low-level `request/1` function instead
- **Removed `parse/2`** - use `create/1` with a `:schema` option instead
- **Removed `collect_stream/1`**
- **Changed schema syntax** - replaced `Schema.object/2`, `Schema.string/1` etc. with simple maps

### Added
- `create/2` can be used to follow up on a previous response
- `create!/1` and `create!/2` raise an error if the response is not successful
- `run/2` and `run!/2` functions for automatic function calling loops
  - Takes a list of available functions and automatically handles function calls
  - Continues conversation until a final response without function calls is received
  - Returns a list of all responses generated during the conversation
  - Supports both map and keyword list function definitions
- `list_models/0` and `list_models/1` to return the list of available OpenAI models
- `:schema` option to `create/1` to specify the schema of the response body
- `Schema.build_output/1` to build the output schema for the response body
- `Schema.build_function/3` to build the function schema for tool calling
- `:stream` callback function option to `create/1` that will be called on every event
- `json_events/1` helper to `Responses.Stream` for streaming JSON events with Jaxon

### Changed
- `create/1` now returns a `Response` struct containing the generated response body, text, parsed JSON, and cost information
- `text_deltas/1` is moved to `Responses.Stream`

## 0.3.0

### Breaking Changes
- **Removed positional parameters** from `create`, `stream`, and `parse` functions. Use keyword lists or maps for parameters instead.

Instead of `OpenAIResponses.create("model", "prompt")`, use `OpenAIResponses.create(model: "model", prompt: "prompt")`.

- **Changed parse response format**. The structure of `parse` return has changed: instead of the parsed response,
  it now returns a map with the following keys:
  - parsed: the parsed result
  - raw_response: the raw response received from OpenAI, which can be used to e.g. calculate the cost
  - token_usage: information about the token usage

- **Removed Config module**. Configuration handling has been streamlined. (Commit: 88b812e)
- **Removed parse_stream function**. This function was not working as intended, and is removed in this release. (Commit: 9723ccb)
- **Removed explicit instructions message in parse**. This should now be handled by the developer. (Commit: f8addc0)

### Added
- **Cost calculations** for various models including 4.1 models and chatgpt-4o-latest. (Commits: 2985d94, 70d68ad, 4f2cdc3)
- **Option to log requests** for debugging or monitoring purposes. (Commit: d4d56b5)

### Changed
- **Increased default timeout** to 60 seconds from a previous value. (Commit: 4a01b66)

### Fixed
- **Fixed tests** across multiple commits to ensure functionality and improve coverage. (Commits: c78858c, 18c535a, 804522e, c594688, d637a73)

### Documentation
- **Updated documentation** to reflect new features, response usage, and tutorial content. (Commits: d1bc204, f07d990, 03031e6, a4ac509)
