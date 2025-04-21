# Technical Context

*This document details the technologies used, development setup, technical constraints, dependencies, and tool usage patterns for the `openai_responses` Elixir library.*

## Core Technologies

- **Programming Language:** Elixir (~> 1.18)
- **HTTP Client:** Req (~> 0.5)
- **JSON Parsing:** Jason (~> 1.4)
- **Arbitrary Precision Numbers:** Decimal (~> 2.0) (Likely used for handling potential numeric values in API responses accurately)

## Development Environment Setup

- Requires Elixir installed (version compatible with ~> 1.18).
- Uses `mix` (Elixir's build tool) for dependency management (`mix deps.get`), compilation (`mix compile`), testing (`mix test`), and documentation generation (`mix docs`).
- Standard Elixir project structure.

## Technical Constraints

- **External API Dependency:** Reliant on the availability and behavior of the OpenAI Responses API.
- **Elixir Version:** Requires Elixir 1.18 or later.

## Key Dependencies

- **`req`:** Used for all HTTP communication with the OpenAI API, including request building, execution, and streaming.
- **`jason`:** Used for encoding Elixir data structures into JSON for API requests and decoding JSON responses from the API.
- **`decimal`:** Used to handle numeric values without precision loss.
- **`ex_doc`:** (Development only) Used to generate API documentation from source code comments and extra files (like README.md).

## Tool Usage Patterns

- **`mix`:** Central build tool for managing dependencies, compiling, running tests, and other development tasks.
- **`ex_doc`:** Standard tool for generating documentation, configured in `mix.exs` to include specific guides and structure the sidebar.
- **`.formatter.exs`:** (Presence inferred from file list) Likely used with `mix format` for code formatting consistency.
- **`.gitignore`:** Standard Git ignore file, likely includes build artifacts (`_build/`), dependencies (`deps/`), etc.
- **`.prettierrc`:** (Presence inferred from file list) Suggests Prettier might be used for formatting non-Elixir files (like Markdown in `docs/`).
