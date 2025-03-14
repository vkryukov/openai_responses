# OpenAI Responses - Development Guide

## Commands

- Build: `mix compile`
- Test all: `mix test`
- Test single file: `mix test test/path/to/file.exs`
- Test single test: `mix test test/path/to/file.exs:line_number`
- Format code: `mix format`
- Check compilation warnings: `mix compile --warnings-as-errors`
- Interactive console: `iex -S mix`
- Generate docs: `mix docs` (requires ex_doc dependency)

## Style Guidelines

- **Naming**: snake_case for variables/functions, CamelCase for modules
- **Documentation**: Always add @moduledoc and @doc with examples
- **Formatting**: Follow Elixir formatter defaults (run `mix format`)
- **Modules**: One module per file, named to match file path
- **Function Order**: Public functions first, private functions (defp) after
- **Error Handling**: Use pattern matching and with statements over try/rescue
- **Tests**: Write doctests for examples, regular tests for edge cases
- **Imports**: Avoid wildcard imports, prefer explicit function imports
- **Pipe Operator**: Use |> for data transformations when appropriate

## API Documentation

- API documentation is located in openai_docs/
- It might reference some other APIs, functions, formats, etc. that are not
  present in the folder. If you need to references them, explain to the user
  what's missing and ask the user to update the folder with missing docs.

