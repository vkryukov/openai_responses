# Structured Outputs

This document explains how to use the structured outputs feature with the OpenAI Responses Elixir library.

## Introduction

Structured Outputs is a feature that ensures the model will always generate responses that adhere to your supplied JSON Schema, so you don't need to worry about the model omitting a required key, or hallucinating an invalid enum value.

The OpenAI Responses Elixir library provides a simple, idiomatic way to define schemas and parse responses with structured outputs. This library supports the latest OpenAI API format for structured outputs.

## Basic Usage

```elixir
alias OpenAI.Responses
alias OpenAI.Responses.Schema

# Define a schema
calendar_event_schema = Schema.object(%{
  name: :string,
  date: :string,
  participants: {:array, :string}
})

# Create a response with structured output
{:ok, event} = Responses.parse(
  "gpt-4o", 
  "Alice and Bob are going to a science fair on Friday.", 
  calendar_event_schema,
  schema_name: "event"
)

# Access the parsed data
IO.puts("Event: #{event["name"]} on #{event["date"]}")
IO.puts("Participants: #{Enum.join(event["participants"], ", ")}")
```

## Defining Schemas

### Simple Types

For simple types without constraints, you can use atoms directly:

```elixir
schema = Schema.object(%{
  name: :string,
  age: :integer,
  is_active: :boolean,
  scores: {:array, :number}
})
```

### Types with Constraints

For types with constraints or additional options, use the corresponding functions:

```elixir
schema = Schema.object(%{
  username: Schema.string(min_length: 3, max_length: 20),
  rating: Schema.number(minimum: 0, maximum: 5),
  tags: Schema.array(:string, min_items: 1, max_items: 5)
})
```

### Nested Objects

You can define nested objects:

```elixir
schema = Schema.object(%{
  user: Schema.object(%{
    name: :string,
    email: Schema.string(format: "email")
  }),
  preferences: Schema.object(%{
    theme: :string,
    notifications: :boolean
  })
})
```

### Arrays

Arrays can be defined in two ways:

```elixir
# Simple array of strings
tags_schema = {:array, :string}

# Array with constraints
tags_schema = Schema.array(:string, min_items: 1, max_items: 5)

# Array of objects
steps_schema = Schema.array(
  Schema.object(%{
    explanation: :string,
    output: :string
  })
)
```

### Nullable Fields

You can make fields nullable:

```elixir
schema = Schema.object(%{
  middle_name: Schema.nullable(:string),
  address: Schema.nullable(
    Schema.object(%{
      street: :string,
      city: :string,
      zip: :string
    })
  )
})
```

## Parsing Responses

### Regular Parsing

Use the `parse/4` function to get a structured response:

```elixir
{:ok, data} = Responses.parse(
  "gpt-4o", 
  "Extract information from this text...", 
  my_schema
)
```


## Examples

See the `examples/structured_output_example.exs` file for complete examples of using structured outputs.

## Supported Models

Structured Outputs is available in OpenAI's latest large language models, starting with GPT-4o:

- `gpt-4.5-preview-2025-02-27` and later
- `o3-mini-2025-1-31` and later
- `o1-2024-12-17` and later
- `gpt-4o-mini-2024-07-18` and later
- `gpt-4o-2024-08-06` and later

Older models like `gpt-4-turbo` and earlier may use JSON mode instead.

## API Implementation Details

This library implements the latest OpenAI API format for structured outputs, which uses the `text` parameter with a format specification instead of the older `response_format` parameter. The implementation handles both the direct API response format and streaming responses.

Key features of the implementation:

- Automatic handling of the new API format with the `text` parameter
- Support for schema validation with `additionalProperties: false` by default
- Proper extraction of structured data from both regular and streaming responses
- Comprehensive error handling for JSON parsing and schema validation
