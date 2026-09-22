# Troubleshooting

## Named credential not found

Typical message:

```text
The callout couldn't access the endpoint. You might not have the required permissions,
or the named credential "Jev_API" might not exist.
```

Check that:

- the Named Credential API name is exactly `Jev_API`, or `JevForceConfig.namedCredential` matches the custom name;
- the URL is `https://api.typesafe.ai` without `/v1/systemone` duplicated;
- the running user has access to the mapped External Credential principal.

## HTTP 401: authentication failed

Check the External Credential custom header:

```text
Authorization
{!'Bearer ' & $Credential.TypeSafe_API_Auth.apiKey}
```

Also verify that **Generate Authorization Header** is disabled, formulas in HTTP headers are enabled, the key has not expired or been revoked, and the principal parameter is named `apiKey`.

## HTTP 403: permission denied

The credential may be valid while the Salesforce user lacks principal access, or the TypeSafe account may not permit the requested operation. Check the Permission Set mapping and provider account access.

## HTTP 404: endpoint not found

The Named Credential should contain only the base URL:

```text
https://api.typesafe.ai
```

JevForce appends `/v1/systemone` itself.

## HTTP 422 or invalid request

Check that:

- state and instructions are non-null and meaningful;
- Choice has 2–255 options;
- Score has 2–10 ordered levels;
- question IDs are unique in a batched request;
- `JevForceConfig.model` names an available model or alias.

JevForce performs local validation, but the provider can enforce additional contract rules.

## HTTP 429 or 529

The account is rate-limited or the service is overloaded. Do not spin or sleep inside Apex. Enqueue a bounded retry for a later transaction and make the business update idempotent.

## Empty or malformed response

JevForce fails closed with `JevApiException`. Capture safe operational metadata such as time, status, model configuration, record ID, and retry count. Do not log the customer state or credentials.

## Unexpected response structure

This means a required field is missing, has the wrong type, contains an out-of-range probability, or does not match the requested primitive. Check the [verified API notes](JEV_API_NOTES.md) and current official TypeSafe documentation before changing parsing logic.

## Uncommitted work pending

Salesforce does not allow the callout after uncommitted DML in the same transaction. Move the integration into a Queueable implementing `Database.AllowsCallouts`, perform the callout first, and perform DML afterward.

## Calls from a trigger fail or exhaust limits

Do not call Jev once per trigger record. Collect record IDs, enqueue async work, and use one Jev request for multiple judgments only when they legitimately share one state.

## Debugging without leaking data

Enable metadata-only logs temporarily:

```apex
JevForceConfig.debugLogging = true;
```

The library reports question count, status, and latency. Disable logging after investigation. Never add request-body or authorization-header logging.
