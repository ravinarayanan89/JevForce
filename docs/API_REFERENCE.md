# Apex API reference

## JevForce

`JevForce` is the public facade. Its methods validate input, perform the callout, validate the response, and return typed results.

### choice

```apex
public static JevChoiceResult choice(
    JevState state,
    String instructions,
    Map<String, String> choices
)
```

- `state` must not be null.
- `instructions` must not be blank.
- `choices` must contain 2–255 entries with nonblank keys.
- A description may be null, matching Jev's official Choice contract.

Returns:

| Property | Type | Meaning |
| --- | --- | --- |
| `choice` | `String` | Highest-probability option key |
| `confidence` | `Decimal` | Jev confidence from 0 through 1 |
| `probabilities` | `Map<String, Decimal>` | Probability for every option |

### score

```apex
public static JevScoreResult score(
    JevState state,
    String instructions,
    List<String> rubric
)
```

- The rubric must contain 2–10 nonblank ordered levels.
- Levels are numbered from zero.
- The score is a probability-weighted value and can be fractional.

Returns:

| Property | Type | Meaning |
| --- | --- | --- |
| `score` | `Decimal` | Weighted position across the rubric |
| `confidence` | `Decimal` | Jev confidence from 0 through 1 |
| `legend` | `Map<String, String>` | Level index to rubric description |
| `probabilities` | `Map<String, Decimal>` | Level index to probability |

### noul

```apex
public static JevNoulResult noul(
    JevState state,
    String instructions
)
```

Returns `probability`, a `Decimal` from 0 through 1 representing the probability of yes. Noul does not have a separate confidence field and JevForce does not turn it into a Boolean.

### execute

```apex
public static JevResponse execute(JevRequest request)
```

Sends several independently evaluated questions against one shared state in one HTTP callout.

## JevState

```apex
JevState state = new JevState()
    .put('name', 'Acme')
    .put('active', true)
    .put('openCases', 4)
    .put('renewalValue', Decimal.valueOf('42000.50'))
    .put('renewalDate', Date.newInstance(2026, 12, 1));
```

Supported values:

- `String`
- `Boolean`
- `Integer`
- `Long`
- `Decimal`
- `Date`
- `Datetime`
- nested lists and string-keyed maps of supported values
- `null`

Public methods:

| Method | Result |
| --- | --- |
| `put(String, Object)` | Adds or replaces a value and returns the same builder |
| `isEmpty()` | Reports whether the state contains fields |
| `toMap()` | Returns a shallow clone of the state map |
| `toJson()` | Serializes state using Salesforce JSON rules |

SObjects and arbitrary class instances are rejected. JevForce intentionally has no automatic `fromSObject` method.

## JevRequest

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
    .addNoul('escalate', 'Does this need immediate human attention?');
```

Question IDs must be nonblank and unique within the request. Returned answers use the same IDs.

| Method | Purpose |
| --- | --- |
| `addChoice(id, instructions, choices)` | Add a Choice question |
| `addScore(id, instructions, rubric)` | Add a Score question |
| `addNoul(id, instructions)` | Add a Noul question |
| `size()` | Number of questions |

At least one question is required before execution.

## JevResponse

```apex
JevState state = new JevState()
    .put('subject', 'Charged twice')
    .put('description', 'Third contact about the same duplicate payment.');

JevRequest request = new JevRequest(state)
    .addChoice(
        'route',
        'Which team?',
        new Map<String, String>{
            'BILLING' => 'Charges, refunds and invoices',
            'FRAUD' => 'Unauthorized or suspicious activity'
        }
    )
    .addScore(
        'urgency',
        'How urgent?',
        new List<String>{ 'Routine', 'Needs Attention', 'Urgent', 'Critical' }
    )
    .addNoul('escalate', 'Does this need immediate human attention?');

JevResponse response = JevForce.execute(request);

JevChoiceResult route = response.choice('route');
JevScoreResult urgency = response.score('urgency');
JevNoulResult escalation = response.noul('escalate');
```

Response metadata:

| Property | Type | Meaning |
| --- | --- | --- |
| `model` | `String` | Versioned model ID that served the request |
| `inputTokens` | `Integer` | Reported input-token usage |
| `outputTokens` | `Integer` | Reported output-token usage |
| `choices` | `Map<String, JevChoiceResult>` | Choice results by ID |
| `scores` | `Map<String, JevScoreResult>` | Score results by ID |
| `nouls` | `Map<String, JevNoulResult>` | Noul results by ID |

## JevForceConfig

| Static property | Default | Constraint |
| --- | --- | --- |
| `namedCredential` | `Jev_API` | Nonblank API name |
| `model` | `jev-latest` | Nonblank model or alias |
| `timeoutMilliseconds` | `10000` | 1–120000 |
| `debugLogging` | `false` | Logs metadata only |

## Exceptions

| Type | Meaning |
| --- | --- |
| `JevConfigurationException` | Invalid local state, question, rubric, or configuration |
| `JevApiException` | Callout failure, HTTP error, empty/malformed response, or contract mismatch |

Both inherit from `JevException`.
