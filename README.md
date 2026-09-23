# JevForce

**Structured AI decisions for Salesforce Apex.**

> Salesforce is already excellent at executing deterministic business logic. The harder problem is making small judgments from messy business context.
>
> JevForce brings Jev's structured decision primitives to Apex so developers can use AI for judgment while keeping business policy and execution deterministic inside Salesforce.

JevForce is a small, dependency-free Apex SDK for TypeSafe AI's Jev model. It exposes Choice, Score, and Noul as strongly typed Apex methods. It is not an agent framework, workflow engine, or generative-AI wrapper.

## Watch the demo

[![JevForce: Bringing Jev to Salesforce — Faster, Cheaper AI Decisions with Apex](https://i.ytimg.com/vi/5BBIcT-jpnw/hqdefault.jpg)](https://youtu.be/5BBIcT-jpnw)

**[JevForce: Bringing Jev to Salesforce | Faster, Cheaper AI Decisions with Apex](https://youtu.be/5BBIcT-jpnw)**

Watch the JevForce demo for a practical walkthrough of structured Jev decisions inside Salesforce Apex.

## Benchmark snapshot

JevForce includes a reproducible comparison between Jev and Salesforce-managed Agentforce Models API · Opus 4.8. Both providers received the same synthetic Case and Lead state and the same semantic decision criteria. The run requested seven judgments in total: two Choice decisions, two Score decisions, and three Noul probabilities.

| Live observation | Jev | Agentforce Models API · Opus 4.8 | Observed result |
| --- | ---: | ---: | --- |
| Combined elapsed time | **677 ms** | 7,533 ms | Jev was **11.1× faster** |
| Input tokens | **1,376** | 1,421 | Jev used 3.2% fewer |
| Output tokens | **213** | 424 | Jev used **49.8% fewer** |
| Total tokens | **1,589** | 1,845 | Jev used **13.9% fewer** |
| Primary Choice agreement | **2 of 2** | **2 of 2** | Both selected the same Case route and Lead segment |
| Response contract | Typed Apex results | Generated JSON text | Jev requires no application-side text parsing |

Scenario results:

- **Case triage:** 490 ms and 831 tokens with Jev, compared with 3,582 ms and 1,021 tokens with Models API.
- **Lead qualification:** 187 ms and 758 tokens with Jev, compared with 3,951 ms and 824 tokens with Models API.

These figures are one live observation captured on 22 September 2026, not a general performance guarantee. Latency varies with service and network conditions, provider tokenizers differ, and the requests are semantically equivalent rather than wire-identical. The benchmark uses synthetic data and performs no DML.

See the [visual benchmark report](examples/model-comparison/benchmark-report.html), read the [methodology and limitations](examples/model-comparison/README.md), or reproduce the run with [`run-live-benchmark.apex`](examples/model-comparison/scripts/run-live-benchmark.apex).

## Documentation

| Guide | Purpose |
| --- | --- |
| [Getting started](docs/GETTING_STARTED.md) | Install, configure the Named Credential, and make the first call |
| [API reference](docs/API_REFERENCE.md) | Public Apex classes, methods, fields, and validation rules |
| [Async and operations](docs/ASYNC_AND_OPERATIONS.md) | Queueable patterns, governor limits, retries, and observability |
| [Security](docs/SECURITY.md) | Data minimization, credential handling, permissions, and logging |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common configuration, callout, and response failures |
| [Verified Jev contract](docs/JEV_API_NOTES.md) | Official wire format, limits, and documented uncertainties |
| [Case Triage demo](examples/case-triage/README.md) | Complete asynchronous Salesforce example |
| [Lead Qualification demo](examples/lead-qualification/README.md) | Live segmentation, intent scoring, queue routing, and follow-up policy |
| [Models API comparison](examples/model-comparison/README.md) | Optional Agentforce Models API · Opus timing and token benchmark for the demos |

## Architecture

```text
Salesforce records / explicit application state
                    │
                    ▼
                 JevState
                    │
                    ▼
        JevForce facade ──► JevClient
                    │          │
                    │          ▼
                    │   Named Credential
                    │          │
                    │          ▼
                    │   TypeSafe /v1/systemone
                    ▼
     ChoiceResult / ScoreResult / NoulResult
                    │
                    ▼
       deterministic Salesforce policy
```

Jev judges. Salesforce decides. JevForce returns uncertainty; it never chooses a business threshold or performs a business action.

## Verified API contract

The implementation follows TypeSafe's official `POST https://api.typesafe.ai/v1/systemone` contract, including its official multi-question request capability. See [JEV_API_NOTES.md](docs/JEV_API_NOTES.md) for verified fields, responses, current published limits, error behavior, and explicitly documented uncertainties.

## Installation

From the `mydevorg` workspace root, deploy the core source to the `mydevorg` org alias:

```bash
sf project deploy start \
  --source-dir jevforce/force-app \
  --target-org mydevorg
```

To deploy the Case Triage example separately:

```bash
sf project deploy start \
  --source-dir jevforce/examples/model-comparison/force-app \
  --source-dir jevforce/examples/case-triage/force-app \
  --target-org mydevorg
```

To deploy the Lead Qualification example separately:

```bash
sf project deploy start \
  --source-dir jevforce/examples/model-comparison/force-app \
  --source-dir jevforce/examples/lead-qualification/force-app \
  --target-org mydevorg
```

To deploy the core and complete example together from any directory:

```bash
./jevforce/scripts/deploy-mydevorg.sh
```

## Configure the Jev credential

Deploying JevForce creates `Jev_API`, `TypeSafe_API_Auth`, its named principal, bearer-header formula, and the `JevForce Callout Access` Permission Set. Get an API key from the [TypeSafe console](https://console.typesafe.ai); only the protected secret value must be configured manually.

1. In Setup, open **Named Credentials → External Credentials → TypeSafe API Authentication**.
2. Edit the `Jev_API_Principal` principal and add its protected authentication parameter:

   ```text
   Name:  apiKey
   Value: <your Jev API key>
   ```

3. Assign the deployed **JevForce Callout Access** Permission Set to approved users who will run synchronous or asynchronous Jev callouts.

The deployed External Credential adds the `Authorization` header using `{!'Bearer ' & $Credential.TypeSafe_API_Auth.apiKey}`. The deployed Named Credential targets `https://api.typesafe.ai`, disables Salesforce's generated authorization header, and enables header formulas. No Remote Site Setting is required.

If your Salesforce release presents slightly different Setup labels, keep the same result: the Named Credential named `Jev_API` must target `https://api.typesafe.ai` and inject `Authorization: Bearer <secret>` outside Apex.

To use a differently named credential, configure it before the first callout:

```apex
JevForceConfig.namedCredential = 'My_Jev_Credential';
```

## Quick start

```apex
JevState state = new JevState()
    .put('subject', 'Charged twice')
    .put('description', 'I was charged twice and need help immediately.')
    .put('priority', 'High')
    .put('customerTier', 'Platinum')
    .put('previousCases', 3);

JevChoiceResult route = JevForce.choice(
    state,
    'Which support team best matches this case?',
    new Map<String, String>{
        'BILLING' => 'Charges, refunds, duplicate payments and invoices',
        'FRAUD' => 'Unauthorized transactions or suspicious activity',
        'TECHNICAL' => 'Technical product problems',
        'ACCOUNT' => 'Login, access and account management'
    }
);

System.debug(route.choice);        // Observed: BILLING
System.debug(route.confidence);    // Observed: 1.0
System.debug(route.probabilities); // Observed: {BILLING=1.0, FRAUD=0.0, TECHNICAL=0.0, ACCOUNT=0.0}

/*
Live Jev API response captured on 2026-09-23:
{
  "model": "jev-1.13.0",
  "answers": {
    "result": {
      "type": "choice",
      "choice": "BILLING",
      "confidence": 1.0,
      "probabilities": {
        "BILLING": 1.0,
        "FRAUD": 0.0,
        "TECHNICAL": 0.0,
        "ACCOUNT": 0.0
      }
    }
  },
  "usage": { "input_tokens": 413, "output_tokens": 54 }
}
*/
```

## Choice

Choice selects exactly one caller-defined option. JevForce returns the selected key, full probability map, and Jev confidence.

```apex
JevState state = new JevState()
    .put('subject', 'Charged twice')
    .put('description', 'Two identical card charges appear on my statement.');

Map<String, String> choices = new Map<String, String>{
    'BILLING' => 'Charges, refunds, duplicate payments and invoices',
    'FRAUD' => 'Unauthorized transactions or suspicious activity',
    'TECHNICAL' => 'Technical product problems',
    'ACCOUNT' => 'Login, access and account management'
};

String question = 'Which support team best matches this case?';
Decimal applicationThreshold = 0.70;

JevChoiceResult result = JevForce.choice(state, question, choices);

System.debug(result.choice);        // Observed: BILLING
System.debug(result.confidence);    // Observed: 1.0
System.debug(result.probabilities); // Observed: {BILLING=1.0, FRAUD=0.0, TECHNICAL=0.0, ACCOUNT=0.0}

if (result.confidence >= applicationThreshold) {
    // Salesforce-owned routing policy
}

/*
Live Jev API response captured on 2026-09-23:
{
  "model": "jev-1.13.0",
  "answers": {
    "result": {
      "type": "choice",
      "choice": "BILLING",
      "confidence": 1.0,
      "probabilities": {
        "BILLING": 1.0,
        "FRAUD": 0.0,
        "TECHNICAL": 0.0,
        "ACCOUNT": 0.0
      }
    }
  },
  "usage": { "input_tokens": 383, "output_tokens": 54 }
}
*/
```

`state`, `question`, `choices`, and `applicationThreshold` are application-owned variables. JevForce sends the first three to Jev; the confidence threshold remains entirely inside Salesforce policy. The response is one observed live result and may change with model versions or input wording.

A Choice requires 2–255 nonblank option keys. Descriptions may be null, matching the official contract, though meaningful descriptions generally produce a clearer rubric.

## Score

Score rates state against 2–10 ordered levels. Level numbers begin at zero and the returned probability-weighted score can be fractional.

```apex
JevState state = new JevState()
    .put('subject', 'Charged twice and nobody is helping me')
    .put('description', 'This is my third contact and I need this resolved now.')
    .put('customerTier', 'Platinum')
    .put('previousCases', 3);

String question = 'Assess the urgency of this customer issue.';
List<String> rubric = new List<String>{
    'Routine',
    'Needs Attention',
    'Urgent',
    'Critical'
};

JevScoreResult urgency = JevForce.score(
    state,
    question,
    rubric
);

System.debug(urgency.score);         // Observed: 2.56
System.debug(urgency.confidence);    // Observed: 0.56
System.debug(urgency.legend);        // Observed: {0=Routine, 1=Needs Attention, 2=Urgent, 3=Critical}
System.debug(urgency.probabilities); // Observed: {0=0.0, 1=0.0, 2=0.44, 3=0.56}

/*
Live Jev API response captured on 2026-09-23:
{
  "model": "jev-1.13.0",
  "answers": {
    "result": {
      "type": "score",
      "score": 2.56,
      "confidence": 0.56,
      "legend": {
        "0": "Routine",
        "1": "Needs Attention",
        "2": "Urgent",
        "3": "Critical"
      },
      "probabilities": {
        "0": 0.0,
        "1": 0.0,
        "2": 0.44,
        "3": 0.56
      }
    }
  },
  "usage": { "input_tokens": 362, "output_tokens": 17 }
}
*/
```

The rubric order defines the scale: `Routine` is level `0` and `Critical` is level `3`. Jev may return a fractional score because it is calculated from the complete distribution. The displayed response is one live observation, not a fixed expected value.

## Noul

Noul returns the probability that a proposition is true. It deliberately does not return or fabricate a boolean or separate confidence.

```apex
JevState state = new JevState()
    .put('subject', 'Charged twice and nobody is helping me')
    .put('description', 'This is my third contact and I need help immediately.')
    .put('customerTier', 'Platinum');

String proposition =
    'Does the evidence suggest this case warrants immediate human escalation?';

JevNoulResult escalation = JevForce.noul(
    state,
    proposition
);

System.debug(escalation.probability); // Observed: 0.88

// Salesforce owns this threshold and the resulting action.
Decimal escalationThreshold = 0.85;
Boolean shouldEscalate = escalation.probability >= escalationThreshold;

/*
Live Jev API response captured on 2026-09-23:
{
  "model": "jev-1.13.0",
  "answers": {
    "result": {
      "type": "noul",
      "noul": 0.88
    }
  },
  "usage": { "input_tokens": 323, "output_tokens": 20 }
}
*/
```

Noul returns a probability, not a boolean. The raw API field is named `noul`; JevForce exposes it as `escalation.probability`. `shouldEscalate` is derived by the consuming Salesforce application and is not part of JevForce. The displayed response is one live observation and may vary.

## One state, multiple questions

The official Jev API evaluates many questions independently against one state in one request. Use this to conserve Salesforce callouts:

```apex
JevState state = new JevState()
    .put('subject', 'Charged twice')
    .put('description', 'Third contact about the same duplicate payment.');

Map<String, String> choices = new Map<String, String>{
    'BILLING' => 'Charges, refunds and invoices',
    'FRAUD' => 'Unauthorized or suspicious activity'
};

List<String> rubric = new List<String>{
    'Routine', 'Needs Attention', 'Urgent', 'Critical'
};

JevRequest request = new JevRequest(state)
    .addChoice('route', 'Which team?', choices)
    .addScore('urgency', 'How urgent?', rubric)
    .addNoul('escalate', 'Does this require immediate human attention?');

JevResponse response = JevForce.execute(request);
JevChoiceResult route = response.choice('route');
JevScoreResult urgency = response.score('urgency');
JevNoulResult escalation = response.noul('escalate');
```

This is native API fan-out, not artificial client-side batching.

## Live Case Triage demo

The [Case Triage example](examples/case-triage/README.md) includes a Case record-page LWC, six deployable queues, an interactive Apex controller, and an optional Queueable pattern. The live component obtains issue routing, sentiment, risk-hold, and immediate-attention judgments in one call, then applies deterministic Salesforce policy to update Case ownership, Priority, and escalation.

```text
Case → explicit JevState → one Jev request
                            ├─ Choice: issue route
                            ├─ Score: sentiment
                            ├─ Noul: risk hold
                            └─ Noul: immediate attention
                                      │
                                      ▼
                   Salesforce policy → Queue + Priority + escalation
```

## Live Lead Qualification demo

The [Lead Qualification example](examples/lead-qualification/README.md) adds a Lead record-page LWC, four Lead queues, an interactive Apex controller, focused tests, and four seed scenarios. It obtains sales segment, buying intent, and immediate-follow-up judgments in one call. Salesforce then assigns the Lead queue, sets Rating, and creates at most one open urgent follow-up Task when the application-owned threshold is met.

```text
Lead → explicit JevState → one Jev request
                            ├─ Choice: sales segment
                            ├─ Score: buying intent
                            └─ Noul: immediate follow-up
                                      │
                                      ▼
                  Salesforce policy → Queue + Rating + optional Task
```

## Optional Agentforce Models API · Opus comparison

Both record-page demos include a separate **Agentforce Models API · Opus** action. It runs the same semantic state and decision criteria through Salesforce-managed Opus 4.8, then displays Apex-measured elapsed time and Salesforce-reported input, output, and total tokens beside Jev. The generated output is read-only and never participates in Salesforce policy or DML. See the [Models API comparison guide](examples/model-comparison/README.md).

## Async and governor-limit guidance

- Do not make one callout per record in a trigger loop.
- Enqueue a `Queueable` implementing `Database.AllowsCallouts` after the originating transaction, or use another appropriate async boundary.
- Put multiple independent judgments over the same state in one `JevRequest`.
- Perform the callout before DML in the callout transaction.
- Keep state focused. Jev's published context limits do not override Salesforce heap, request-body, CPU, or callout limits.
- On `429`, `529`, or transient 5xx responses, schedule retry work in a later transaction. Apex should not sleep inside a transaction.
- Design retries to be idempotent and cap attempts. JevForce V1 intentionally does not own job orchestration.

## Explicit state and security

`JevState` accepts String, Boolean, Integer, Long, Decimal, Date, Datetime, lists, maps, and null values. Dates and datetimes use Salesforce JSON serialization. Unsupported objects, including SObjects, are rejected.

There is intentionally no `fromSObject` method. Select each field that may leave Salesforce:

```apex
public static JevState buildSafeCaseState(Id caseId) {
    Case caseRecord = [
        SELECT Subject, Description
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];

    return new JevState()
        .put('subject', caseRecord.Subject)
        .put('description', caseRecord.Description);
}
```

Here, `caseId` is supplied by the caller—for example, a record-page LWC controller or Queueable constructor. Only the two explicitly queried fields are added to outbound Jev state.

Before production use, classify the data you send, enforce your organization's CRUD/FLS and consent policies, check TypeSafe's current legal/data-processing terms, minimize customer content, and choose appropriate retention and audit controls. JevForce never logs request state, response bodies, credentials, or authentication headers.

## Configuration and observability

```apex
JevForceConfig.model = 'jev-1.13.0';       // Optional version pin
JevForceConfig.timeoutMilliseconds = 10000;
JevForceConfig.debugLogging = true;         // Disabled by default
```

Debug logging includes only question count, HTTP status, and latency. It excludes customer state, questions, response data, and secrets. Static configuration lasts only for the current Apex transaction; establish non-default values at the application entry point.

## Error handling

- `JevConfigurationException`: invalid local input or configuration
- `JevApiException`: callout failure, non-2xx status, empty/malformed JSON, or response-contract mismatch

```apex
JevState state = new JevState()
    .put('subject', 'Charged twice')
    .put('description', 'The duplicate charge is still unresolved.');

String proposition = 'Does this case require immediate human attention?';

try {
    JevNoulResult result = JevForce.noul(state, proposition);
} catch (JevConfigurationException error) {
    // Fix local configuration/input; retrying unchanged input will not help.
} catch (JevApiException error) {
    // Apply application-owned fallback or enqueue a bounded transient retry.
}
```

Error messages include safe status information and may include a short top-level provider message. They never include request state or credentials.

## Testing

No test calls the live service. The suite uses `HttpCalloutMock` for Choice, Score, Noul, batched responses, serialization, validation, HTTP errors, malformed JSON, empty responses, Unicode, dates, datetimes, decimals, and a large reasonable state.

```bash
npm test
# or
sf apex run test --target-org mydevorg --test-level RunLocalTests --wait 20 --result-format human
```

See [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes.

## License

Apache License 2.0. See [LICENSE](LICENSE).
