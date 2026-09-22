# Async usage and operations

## Use an asynchronous boundary

Callouts should not be made directly from trigger logic. Enqueue identifiers and query the records again inside a Queueable that implements `Database.AllowsCallouts`.

```apex
public with sharing class EvaluateCaseJob
    implements Queueable, Database.AllowsCallouts {

    private Id caseId;

    public EvaluateCaseJob(Id caseId) {
        this.caseId = caseId;
    }

    public void execute(QueueableContext context) {
        Case record = [
            SELECT Id, Subject, Description
            FROM Case
            WHERE Id = :caseId
        ];

        JevState state = new JevState()
            .put('subject', record.Subject)
            .put('description', record.Description);

        JevNoulResult result = JevForce.noul(
            state,
            'Does this case require immediate human attention?'
        );

        // The callout is complete. Salesforce policy can now perform DML.
        if (result.probability >= 0.85) {
            record.IsEscalated = true;
            update record;
        }
    }
}
```

## Reduce callouts with native fan-out

When judgments share the same state, send them in one `JevRequest` rather than issuing separate calls. Jev evaluates the questions independently in parallel.

Do not combine unrelated records into one state merely to reduce callouts. Every question sees the entire shared state, so state boundaries should reflect the business decision boundary.

## Transaction ordering

Within the asynchronous transaction:

1. Query the records and reference data needed to build explicit state.
2. Execute the Jev callout.
3. Apply deterministic Salesforce policy.
4. Perform DML.

Avoid uncommitted DML before the callout.

## Retry policy

JevForce raises exceptions instead of sleeping or retrying within an Apex transaction.

Suggested application policy:

| Failure | Default handling |
| --- | --- |
| `400` or `422` | Do not retry unchanged input; investigate request validation |
| `401` or `403` | Do not retry immediately; repair credential access/configuration |
| `404` | Verify Named Credential base URL and JevForce endpoint version |
| `429` | Retry later with bounded exponential backoff |
| `500`–`529` | Retry later with bounded exponential backoff |
| Timeout/callout failure | Retry only when the operation is idempotent |
| Contract mismatch | Fail closed, retain diagnostics, and investigate provider/API changes |

A production retry implementation should track attempt count, next-attempt time, last safe error category, and the stable business record ID. Never persist the API key or raw authorization header.

## Governor limits

- Avoid one callout per record in loops.
- Keep state small enough for Apex heap and HTTP request limits, even when Jev accepts a larger context.
- Do not estimate tokens in Apex; tokenization is provider-specific.
- Use separate Queueables when records do not share a meaningful state.
- Design for partial failure and idempotent updates.
- Remember that each Queueable execution receives its own transaction limits.

## Observability

Debug logging is disabled by default:

```apex
JevForceConfig.debugLogging = true;
```

Enabled logs contain only:

- question count
- HTTP status
- callout latency

They do not contain state, question text, response content, API keys, or headers. If the consuming application stores richer telemetry, review it as a separate data-egress and retention decision.

The batched `JevResponse` also exposes the serving model and token usage. These values can be aggregated without storing customer state.

## Model aliases

`jev-latest` can move to a newer stable model. If business thresholds are calibrated to a particular model version, pin `JevForceConfig.model` to that version and re-evaluate before upgrading.
