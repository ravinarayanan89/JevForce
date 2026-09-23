# Getting started

This guide takes a Salesforce developer from source deployment to the first Jev Choice call.

## Prerequisites

- A Salesforce org that supports Apex callouts and modern Named Credentials
- Salesforce CLI (`sf`)
- A Jev API key from the [TypeSafe console](https://console.typesafe.ai)
- Permission to create External Credentials, Named Credentials, and Permission Sets

## 1. Deploy JevForce

From the `mydevorg` workspace root:

```bash
sf project deploy start \
  --source-dir jevforce/force-app \
  --target-org mydevorg
```

The core library has no managed-package or third-party Apex dependency.

## 2. Configure the deployed External Credential secret

The deployment creates the External Credential, Named Credential, named principal, custom bearer header, and Permission Set. In Salesforce Setup:

1. Open **Named Credentials → External Credentials → TypeSafe API Authentication**.
2. Edit the deployed `Jev_API_Principal` and add its protected authentication parameter:
   - Name: `apiKey`
   - Value: your Jev API key
3. Assign the deployed **JevForce Callout Access** Permission Set to each approved calling user.

The secret remains encrypted in Salesforce credential storage. Do not copy it into Apex, Custom Metadata, Custom Settings, or repository files. The bearer-header formula is already deployed.

## 3. Verify the deployed Named Credential

The deployment creates this Named Credential:

| Setting | Value |
| --- | --- |
| Label | `Jev API` |
| API Name | `Jev_API` |
| URL | `https://api.typesafe.ai` |
| External Credential | `TypeSafe_API_Auth` |
| Generate Authorization Header | Disabled |
| Allow Formulas in HTTP Header | Enabled |

Assign the principal's Permission Set and required User External Credentials object access to every user context that can run the callout—including the user that enqueues asynchronous work.

No Remote Site Setting is needed because Apex uses `callout:Jev_API/v1/systemone`.

## 4. Make the first call

```apex
JevState state = new JevState()
    .put('subject', 'Charged twice')
    .put('description', 'This is my third attempt to resolve a duplicate charge.')
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
  "usage": { "input_tokens": 407, "output_tokens": 54 }
}
*/
```

`choice` is one of the supplied keys. `probabilities` contains Jev's probability for every option. `confidence` is Jev's confidence derived from the distribution.

## 5. Apply Salesforce policy

Keep thresholds and actions outside JevForce:

```apex
public static Boolean mayRouteAutomatically(JevChoiceResult route) {
    Decimal routingThreshold = 0.85;
    return route.confidence >= routingThreshold;
}
```

The caller passes the `JevChoiceResult` created in the complete example immediately above. `routingThreshold` and every resulting action belong to the Salesforce application—for example, mapping `route.choice` to a Queue or sending the Case for human review.

The threshold above is only an example. Tune application thresholds against representative labeled data and the cost of a wrong decision.

## Optional configuration

Set configuration before the first callout in each transaction:

```apex
JevForceConfig.namedCredential = 'Jev_API';
JevForceConfig.model = 'jev-latest';
JevForceConfig.timeoutMilliseconds = 10000;
JevForceConfig.debugLogging = false;
```

Configuration is static transaction state; it is not persisted by JevForce.

## Verify the installation

Run the mock-only test suite:

```bash
sf apex run test \
  --test-level RunLocalTests \
  --target-org mydevorg \
  --wait 20 \
  --result-format human
```

Then continue with the [API reference](API_REFERENCE.md), the [Case Triage example](../examples/case-triage/README.md), or the [Lead Qualification example](../examples/lead-qualification/README.md).
