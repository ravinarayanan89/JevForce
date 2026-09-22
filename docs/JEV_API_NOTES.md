# Verified Jev API contract

Verified on 2026-09-21 against the official TypeSafe AI documentation:

- [HTTP API reference](https://docs.typesafe.ai/api)
- [Quick start](https://docs.typesafe.ai/introduction/quickstart)
- [State](https://docs.typesafe.ai/concepts/state)
- [Models and limits](https://docs.typesafe.ai/models)
- [Choice](https://docs.typesafe.ai/primitives/choice)
- [Score](https://docs.typesafe.ai/primitives/score)
- [Noul](https://docs.typesafe.ai/primitives/noul)

## Transport and authentication

```http
POST https://api.typesafe.ai/v1/systemone
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

JevForce delegates the `Authorization` header to a Salesforce Named Credential. The library never accepts, stores, or logs an API key.

## Request

Every request has these required top-level fields:

```json
{
  "model": "jev-latest",
  "state": {},
  "questions": {}
}
```

- `state`: string, JSON object, or JSON array containing text/structured application state.
- `model`: `jev-latest` by default. As of verification, this aliases `jev-1.13.0`.
- `questions`: a map from caller-selected IDs to typed question objects. IDs are not used for inference.

Question contracts:

- Choice: `{ "type": "choice", "instructions": ..., "criteria": { "option": description } }`; 2–255 options.
- Score: `{ "type": "score", "instructions": ..., "criteria": [ ... ] }`; 2–10 ordered levels, indexed from zero.
- Noul: `{ "type": "noul", "instructions": ... }`; optional true/false criteria are supported by the service but omitted by JevForce V1's intentionally small facade.

The API officially supports mixing multiple questions of all three types in one request. They share one state and are evaluated independently and in parallel. JevForce exposes this as `JevRequest`/`JevForce.execute` and uses it in the demo.

## Response

```json
{
  "model": "jev-1.13.0",
  "answers": {
    "route": {
      "type": "choice",
      "choice": "billing",
      "probabilities": { "billing": 0.88, "technical": 0.12 },
      "confidence": 0.81
    },
    "urgency": {
      "type": "score",
      "score": 1.05,
      "legend": { "0": "Calm", "1": "Frustrated", "2": "Very angry" },
      "probabilities": { "0": 0.0, "1": 0.95, "2": 0.05 },
      "confidence": 0.92
    },
    "escalate": { "type": "noul", "noul": 0.95 }
  },
  "usage": { "input_tokens": 318, "output_tokens": 72 }
}
```

JevForce maps `noul` to the Apex-friendly result property `probability`; it does not manufacture a confidence or boolean.

## Errors and retry behavior

The official API documents:

- `401`: missing/invalid API key
- `422`: request validation failure
- `429`: rate limit exceeded
- `529`: temporary overload

The official SDKs also retry transient `429`, `500`, `502`, `503`, and `504` responses with backoff. Apex cannot safely sleep within a transaction, so V1 raises a typed `JevApiException`; callers should retry in a later Queueable transaction. Other 4xx/5xx statuses, empty bodies, malformed JSON, and contract mismatches are also converted to safe exceptions without exposing request state or credentials.

## Published limits

At verification time, `jev-1.13.0` documented:

- 250,000 tokens/second and 1,200 requests/minute (limits may change dynamically)
- 64k tokens per request across state and all questions
- 32k tokens for state plus the longest single question
- text-only input; state may be a string, object, or array
- maximum 255 Choice options
- 2–10 Score levels

Salesforce has its own stricter transaction callout, heap, CPU, and payload limits. JevForce does not attempt to estimate tokens.

## Explicit uncertainties and V1 decisions

- The official API reference does not document a maximum number of questions per request. JevForce does not invent one.
- The error body is described as JSON but no stable error-object schema is guaranteed. JevForce extracts only a top-level scalar `message`, `detail`, or `error` when present and otherwise reports the HTTP status.
- No idempotency-key contract is documented, so JevForce does not send one.
- Retry headers are documented, but sleeping/retrying synchronously is inappropriate in Apex. Retry scheduling remains application policy.
- The model alias can move. `JevForceConfig.model` defaults to `jev-latest` and can be pinned by the consuming application.

## Minimal Apex architecture

- `JevForce`: public facade and response validation
- `JevClient`: HTTP-only transport
- `JevState`: explicit, fluent state builder
- `JevRequest` / `JevResponse`: official multi-question request support
- typed Choice, Score, and Noul result classes
- typed configuration/API exceptions
- `JevForceConfig`: Named Credential, model, timeout, and metadata-only debug logging

No SObject-wide serializer is provided: callers must explicitly choose outbound fields.
