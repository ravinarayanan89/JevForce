# Contributing to JevForce

Thank you for helping JevForce feel native in Apex.

## Principles

- Keep the public API small and strongly typed.
- Verify Jev wire-contract changes against official TypeSafe documentation before coding.
- Keep judgment in Jev and deterministic policy/action in the consuming Salesforce application.
- Never add credential storage, implicit SObject serialization, or request-payload logging.
- Avoid dependencies in the core library.

## Development

1. Create or select a Salesforce development org.
2. Deploy `force-app` with Salesforce CLI.
3. Run all local tests with `npm test`.
4. Add meaningful `HttpCalloutMock` coverage for every contract or error-handling change.
5. Update `docs/JEV_API_NOTES.md` with the verification date and official source when the provider contract changes.

Do not use a real Jev key in tests, fixtures, debug logs, commits, or issue reports.

## Pull requests

Keep changes focused. Explain the Salesforce use case, public API impact, security implications, official API evidence, and test coverage. New orchestration, agent, generative-AI, and unrelated workflow features are outside V1 scope.
