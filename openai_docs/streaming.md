# Streaming API Documentation

## Streaming

When you create a Response with `stream` set to `true`, the server will emit
server-sent events to the client as the Response is generated. This section
contains the events that are emitted by the server.

### response.created

Emitted when a response is created.

- **response** (`object`): The response that was created.
- **type** (`string`): Always `response.created`.

```json
{
  "type": "response.created",
  "response": {
    "id": "resp_67ccfcdd16748190a91872c75d38539e09e4d4aac714747c",
    "object": "response",
    "created_at": 1741487325,
    "status": "in_progress",
    "error": null,
    "model": "gpt-4o-2024-08-06",
    "output": [],
    "temperature": 1,
    "top_p": 1,
    "truncation": "disabled",
    "metadata": {}
  }
}
```

### response.in_progress

Emitted when the response is in progress.

- **response** (`object`): The response that is in progress.
- **type** (`string`): Always `response.in_progress`.

```json
{
  "type": "response.in_progress",
  "response": {
    "id": "resp_67ccfcdd16748190a91872c75d38539e09e4d4aac714747c",
    "object": "response",
    "created_at": 1741487325,
    "status": "in_progress",
    "error": null,
    "model": "gpt-4o-2024-08-06",
    "output": [],
    "temperature": 1,
    "top_p": 1,
    "truncation": "disabled",
    "metadata": {}
  }
}
```

### response.completed

Emitted when the model response is complete.

- **response** (`object`): Properties of the completed response.
- **type** (`string`): Always `response.completed`.

```json
{
  "type": "response.completed",
  "response": {
    "id": "resp_123",
    "object": "response",
    "created_at": 1740855869,
    "status": "completed",
    "output": [
      {
        "id": "msg_123",
        "type": "message",
        "role": "assistant",
        "content": [
          {
            "type": "output_text",
            "text": "In a shimmering forest under a sky full of stars, a lonely unicorn..."
          }
        ]
      }
    ],
    "temperature": 1,
    "top_p": 1,
    "truncation": "disabled",
    "metadata": {}
  }
}
```

### response.failed

Emitted when a response fails.

- **response** (`object`): The response that failed.
- **type** (`string`): Always `response.failed`.

```json
{
  "type": "response.failed",
  "response": {
    "id": "resp_123",
    "object": "response",
    "created_at": 1740855869,
    "status": "failed",
    "error": {
      "code": "server_error",
      "message": "The model failed to generate a response."
    }
  }
}
```

### response.output_item.added

Emitted when a new output item is added.

- **item** (`object`): The output item that was added.
- **output_index** (`integer`): The index of the added output item.
- **type** (`string`): Always `response.output_item.added`.

```json
{
  "type": "response.output_item.added",
  "output_index": 0,
  "item": {
    "id": "msg_123",
    "status": "in_progress",
    "type": "message",
    "role": "assistant",
    "content": []
  }
}
```

### response.output_text.done

Emitted when text content is finalized.

- **content_index** (`integer`): The index of the finalized content.
- **item_id** (`string`): The ID of the output item.
- **output_index** (`integer`): The index of the output item.
- **text** (`string`): The finalized text content.
- **type** (`string`): Always `response.output_text.done`.

```json
{
  "type": "response.output_text.done",
  "item_id": "msg_123",
  "output_index": 0,
  "content_index": 0,
  "text": "In a shimmering forest under a sky full of stars..."
}
```

### response.refusal.done

Emitted when refusal text is finalized.

- **content_index** (`integer`): The index of the refusal text.
- **item_id** (`string`): The ID of the output item.
- **output_index** (`integer`): The index of the output item.
- **refusal** (`string`): The finalized refusal text.
- **type** (`string`): Always `response.refusal.done`.

```json
{
  "type": "response.refusal.done",
  "item_id": "item-abc",
  "output_index": 1,
  "content_index": 2,
  "refusal": "final refusal text"
}
```

### error

Emitted when an error occurs.

- **code** (`string` or `null`): The error code.
- **message** (`string`): The error message.
- **param** (`string` or `null`): The error parameter.
- **type** (`string`): Always `error`.

```json
{
  "type": "error",
  "code": "ERR_SOMETHING",
  "message": "Something went wrong",
  "param": null
}
```

---

This document provides a structured API reference for streaming response events.
