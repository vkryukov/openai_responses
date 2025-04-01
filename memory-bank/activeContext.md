# Active Context

*This document tracks the current focus, recent changes, and immediate next steps. It also captures active decisions, important patterns, and project insights.*

## Current Focus

- Addressing user query about default timeouts and how to configure them.

## Recent Changes

- Investigated `Req` default timeouts and how `openai_responses` uses `Req`.
- Modified `lib/openai_responses/client.ex` to set a default `:recv_timeout` of 30,000ms (30 seconds) in `Client.new/1`. This addresses the issue of timeouts with default settings for longer API calls.
- Confirmed that users can still override this default using the `:req_options` keyword list when calling library functions or `Client.new/1`.

## Next Steps

- Update `progress.md` and `systemPatterns.md` to reflect the new default timeout.
- Finalize the task completion.

## Active Decisions & Considerations

- How to best represent the project's structure and functionality within the Memory Bank framework.
- Ensuring the initial population accurately reflects the state described in the README.

## Important Patterns & Preferences

- **Modularity:** The library seems organized into core (`OpenAI.Responses`), client (`OpenAI.Responses.Client`), and helper (`OpenAI.Responses.Helpers`) modules.
- **Dependency:** Relies heavily on the `Req` library for HTTP requests and streaming.
- **Configuration:** Offers multiple ways to configure the API key (env var, direct param, client).
- **Streaming:** Uses `Req`'s `:into` for streaming and provides helpers (`text_deltas`, `collect_stream`).
- **Input Handling:** Specific helpers for creating structured input, including image handling (`create_input_message`).

## Learnings & Insights

- The project is an Elixir client library specifically for the OpenAI Responses API.
- It prioritizes ease of use through helper functions and clear API calls.
- Streaming and structured input (especially images) are key supported features.
- Documentation includes a README, a Livebook tutorial, and generated API docs.
