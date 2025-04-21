# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0]

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
