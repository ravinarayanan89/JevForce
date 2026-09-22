# Security guide

## Explicit outbound data

JevForce never serializes a whole SObject. Developers must select every outbound value:

```apex
JevState state = new JevState()
    .put('subject', caseRecord.Subject)
    .put('description', caseRecord.Description);
```

Before adding a field, determine whether it is necessary for the judgment. Exclude secrets, authentication material, credentials, session identifiers, and unrelated personal information.

## Credential storage

- Store the Jev API key in an External Credential principal authentication parameter.
- Inject the bearer header using an External Credential custom header.
- Never store the key in Apex, Custom Metadata, Custom Settings, Custom Objects, environment files committed to Git, or debug logs.
- Rotate the key through Salesforce Setup without changing Apex.
- Disable Salesforce's generated authorization header when using the custom bearer header.

## Least privilege

- Map the External Credential principal to a dedicated Permission Set.
- Assign it only to users or integration contexts that require Jev callouts.
- Grant only the required User External Credentials object permissions.
- Review the effective user for Queueable, Batch, Scheduled, Flow, and platform-event entry points.

## Salesforce record access

JevForce does not decide CRUD, field-level security, sharing, or consent policy. The calling application must enforce the policy appropriate to its entry point.

For user-facing code, consider `WITH USER_MODE`, user-mode database operations, and `Security.stripInaccessible` where appropriate. For integration/system code, document why its execution context is required and still minimize state explicitly.

## Logging and errors

JevForce does not log:

- state or request payloads
- question instructions or criteria
- response bodies
- authorization headers or API keys

Provider error details are limited to a short top-level scalar `message`, `detail`, or `error`. The raw request is never included in a thrown exception.

## Data governance checklist

- Classify every outbound field.
- Confirm the legal basis and consent requirements for processing.
- Review TypeSafe's current service terms, privacy terms, and data-processing options.
- Define retention rules for any application-owned telemetry.
- Test non-English workloads and sensitive classifications on representative data.
- Require human review when uncertainty or impact warrants it.
- Re-evaluate thresholds after model-version changes.

## Reporting a vulnerability

Do not include live credentials, customer records, or sensitive payloads in a public GitHub issue. Report security problems privately to the repository maintainers and rotate any credential that may have been exposed.
