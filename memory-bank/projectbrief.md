# Project Brief

*This is the foundational document for the `openai_responses` Elixir library. It defines the core requirements, goals, and scope.*

## Core Goals

- Provide a simple and intuitive Elixir client for interacting with the OpenAI Responses API.
- Offer helper functions to easily work with API responses (extract text, check status, handle streaming, etc.).
- Support core OpenAI Responses API features like basic requests, tool usage, structured input (text and images), and streaming.

## Key Requirements

- Dependency on the `Req` HTTP client library.
- Ability to configure the OpenAI API key via environment variables, direct function arguments, or a custom client instance.
- Functions for creating, retrieving, deleting responses, and listing input items.
- Robust handling of streaming responses using `Req`'s `:into` mechanism.
- Helper functions for common tasks like extracting text output, token usage, status checks, and refusal handling.
- Support for structured input, including local image file encoding.

## Scope

- Focus specifically on the OpenAI Responses API endpoints.
- Provide an Elixir interface, leveraging Elixir's features (e.g., streams).
- Include basic examples and documentation (README, Livebook tutorial, generated API docs).
- Does not aim to cover other OpenAI APIs (e.g., Embeddings, Fine-tuning) within this specific library.
