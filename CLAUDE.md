# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenAI.Responses is an Elixir client library for the OpenAI Responses API. It provides a simple interface for creating AI responses, with support for streaming, structured outputs, function calling, and automatic cost calculation.

## Essential Commands

### Development
```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run tests (excludes API tests by default)
mix test

# Run all tests including API integration tests
mix test --include api

# Generate documentation
mix docs
```

## Architecture

### Core Modules

**`OpenAI.Responses`** - Main API interface
- `create/1` and `create/2` - Synchronous or streaming AI responses
- `create!/1` and `create!/2` - Same as create but raises on error
- `stream/1` - Returns an Enumerable for stream processing
- `list_models/0` and `list_models/1` - Lists available OpenAI models
- `request/1` - Low-level API request function
- Default model: "gpt-4.1-mini"

**`OpenAI.Responses.Response`** - Response handling
- Struct with fields: `text`, `body`, `parsed`, `parse_error`, `cost`
- `extract_text/1` - Extracts assistant messages from raw API responses (now idempotent)
- `extract_json/1` - Extracts structured data from JSON responses (auto-calls extract_text)
- `extract_function_calls/1` - Extracts function call results from responses
- `calculate_cost/1` - Calculates usage costs using Decimal for precision

**`OpenAI.Responses.Stream`** - Streaming functionality
- `stream_with_callback/2` - Streams with callback function and returns `{:ok, %Response{}}` with complete response data
- `stream/1` - Returns Elixir Stream that yields `{:ok, chunk}` or `{:error, reason}` tuples
- `text_deltas/1` - Extracts text deltas from event streams, filters for text content only
- `json_events/1` - Combines streaming with incremental JSON parsing using Jaxon library
- `delta/1` - Helper callback function for simple text streaming (processes text deltas only)
- `print_unique_events/0` - Debug helper that prints each unique event type once
- Event format: `{:ok, %{event: "event_type", data: %{...}}}` or `{:error, reason}`

**`OpenAI.Responses.Schema`** - Structured output and function calling support
- `build_output/1` - Converts Elixir syntax to JSON Schema for structured outputs
- `build_function/3` - Builds function calling tool schemas (name, description, parameters)
- Used for `output_schema` parameter and function calling tools in API calls

### Configuration

API Key (required) - set via one of:
1. Environment variable: `OPENAI_API_KEY`
2. Application config: `config :openai_responses, :openai_api_key, "your-key"`

### Key Patterns

1. All API responses include automatic cost calculation using the `OpenAI.Responses.Pricing` module
2. Streaming responses use Server-Sent Events (SSE) format and return processed `Response` structs
3. The library uses `req` for HTTP with automatic retries and error handling
4. Text extraction is automatic and idempotent - `Response.text` contains assistant messages
5. JSON extraction is automatic for structured outputs - `Response.parsed` contains structured data
6. Function call extraction is automatic - `Response.function_calls` contains function call data
7. `extract_json/1` automatically calls `extract_text/1` if text is not already extracted
8. Streaming with callbacks now returns `{:ok, %Response{}}` with complete metadata
9. All extraction functions are idempotent and safe to call multiple times

### Testing

- API integration tests (tagged with `:api`) make real API calls
- Test files mirror the lib structure (e.g., `lib/responses/stream.ex` → `test/responses/stream_test.exs`)
