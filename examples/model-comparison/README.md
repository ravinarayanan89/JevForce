# Agentforce Models API · Opus comparison

This optional demo layer compares Jev with **Agentforce Models API · Opus 4.8**, managed by Salesforce.

It is deliberately outside the JevForce core. JevForce remains a small structured-decision SDK with no generative-model dependency.

## What the comparison measures

The Case and Lead components expose a second **Agentforce Models API · Opus** button. The comparison sends the same record state, questions, choices, and scoring rubric used by the Jev request, expressed as a compact text-generation prompt.

The UI displays:

- elapsed wall-clock time measured in Apex;
- input, output, and total tokens reported by Salesforce Models API;
- the generated JSON for inspection;
- the equivalent Jev token counts and elapsed time after the Jev action runs.

This is a semantic task comparison, not an identical wire request. Jev receives native typed questions and produces typed probabilities. Agentforce Models API receives a generated text prompt and produces JSON text that must be parsed and validated before software could safely use it.

Agentforce Models API output is read-only in this demo. It never changes ownership, Rating, Priority, escalation, or Tasks.

## Live benchmark report

Open [`benchmark-report.html`](benchmark-report.html) for the detailed Case and Lead comparison captured from live anonymous Apex. The report includes latency, token efficiency, normalized scores, probability distributions, agreement, raw generated JSON, methodology, and limitations.

Re-run the same synthetic, zero-DML benchmark with:

```bash
sf apex run \
  --file examples/model-comparison/scripts/run-live-benchmark.apex \
  --target-org mydevorg
```

## Model and billing

The implementation uses:

```text
sfdc_ai__DefaultBedrockAnthropicClaude48Opus
```

Salesforce lists this as a Salesforce-managed model operating inside the Salesforce Trust Boundary. Models API calls consume Einstein Requests and are subject to Salesforce usage, billing, regional availability, and rate limits.

- [Salesforce Models API guide](https://developer.salesforce.com/docs/ai/agentforce/guide/models-api.html)
- [Salesforce supported models](https://developer.salesforce.com/docs/ai/agentforce/guide/supported-models.html)
- [Models API Apex reference](https://developer.salesforce.com/docs/ai/agentforce/references/models-apex-api)

## Deploy

Deploy this source directory with either record-page example because both controllers reference the shared benchmark class:

```bash
sf project deploy start \
  --source-dir jevforce/force-app \
  --source-dir jevforce/examples/model-comparison/force-app \
  --source-dir jevforce/examples/case-triage/force-app \
  --source-dir jevforce/examples/lead-qualification/force-app \
  --target-org mydevorg
```
