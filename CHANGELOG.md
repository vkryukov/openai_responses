# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
