# JevForce documentation

JevForce gives Apex applications a small, strongly typed interface to Jev's structured decision primitives.

## Start here

1. [Install and configure JevForce](GETTING_STARTED.md).
2. Build explicit state with `JevState`.
3. Call `JevForce.choice`, `JevForce.score`, or `JevForce.noul`.
4. Use [one batched request](API_REFERENCE.md#jevrequest) when several judgments share the same state.
5. Apply thresholds and business actions in Salesforce code—not in JevForce.

## Guides

- [Getting started](GETTING_STARTED.md)
- [API reference](API_REFERENCE.md)
- [Async and operations](ASYNC_AND_OPERATIONS.md)
- [Security](SECURITY.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Verified Jev API notes](JEV_API_NOTES.md)
- [Intelligent Case Triage example](../examples/case-triage/README.md)

## Core principle

```text
Salesforce supplies explicit state
              ↓
Jev returns structured judgment and uncertainty
              ↓
Salesforce applies policy and takes action
```

JevForce never converts a probability into a business decision on the application's behalf.
