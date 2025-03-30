# Product Context

*This document outlines the "why" behind the `openai_responses` Elixir library, the problems it aims to solve, and the desired user experience.*

## Problem Statement

- Elixir developers need a straightforward way to interact with the OpenAI Responses API without handling raw HTTP requests and response parsing directly.
- Common tasks like handling API keys, managing streaming responses, and extracting specific data from the API response object can be repetitive and error-prone.
- Integrating image inputs (local or remote) requires specific formatting and encoding.

## Proposed Solution

- Provide an Elixir library (`openai_responses`) that abstracts the complexities of the OpenAI Responses API.
- Offer a simple, idiomatic Elixir interface for making API calls (create, get, delete, list items).
- Include helper functions (`OpenAI.Responses.Helpers`) to simplify common operations like configuration, input creation (including image handling), output extraction, streaming management, and status checking.
- Leverage the `Req` library for robust HTTP requests and streaming.

## Target Users

- Elixir developers building applications that need to integrate with OpenAI's Responses API for generative text, vision tasks, or other capabilities offered by the API.

## User Experience Goals

- **Simplicity:** Easy to install, configure, and use for basic API calls.
- **Intuitive:** Function names and module structure should be clear and predictable for Elixir developers.
- **Helpful:** Utility functions should reduce boilerplate code for common tasks.
- **Robust:** Reliable handling of API requests, responses, and especially streaming.
- **Well-documented:** Clear README, examples, and generated API documentation.
