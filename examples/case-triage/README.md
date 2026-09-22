# Live Payment-Service Case Triage

This is the single JevForce example application. It adds a polished Lightning Web Component to the Salesforce Case record page and demonstrates the full philosophy:

> Salesforce provides explicit Case state → Jev returns structured judgments → Salesforce applies routing policy and changes ownership.

The example is written for a fictional digital-payments service and contains no third-party brand dependencies.

## What the component does

When an agent selects **Run JevForce Triage**, `JevCaseTriageController`:

1. Queries the current Case and explicitly selects the state sent outside Salesforce.
2. Sends one live Jev request containing four parallel judgments:
   - issue route using Choice;
   - customer sentiment using Score;
   - risk-hold evidence using Noul;
   - need for immediate attention using Noul.
3. Applies deterministic Salesforce-owned policy.
4. Updates `Case.OwnerId`, `Priority`, and `IsEscalated`.
5. Returns the judgments, uncertainty, selected queue, model, and token usage to the LWC.

```text
┌──────────────────────── Salesforce Case record ────────────────────────┐
│ Subject · Description · Status · Origin · Priority · Current Owner     │
└────────────────────────────────┬────────────────────────────────────────┘
                                 ▼
                         Explicit JevState
                                 ▼
                    One /v1/systemone callout
              ┌──────────────┬──────────────┬──────────────┐
              ▼              ▼              ▼              ▼
          Issue Choice  Sentiment Score  Risk-hold Noul  Attention Noul
              └──────────────┴───────┬──────┴──────────────┘
                                      ▼
                         Salesforce routing policy
                                      ▼
                    Queue owner · Priority · Escalation
```

## Component experience

The `jevCaseTriage` LWC displays:

- current Case number, subject, and owner;
- a visual explanation of the difference between probability, confidence, and Salesforce policy;
- every Choice option as a ranked probability bar, including the selected route;
- every Score level as a distribution column plus the probability-weighted sentiment position;
- complementary Yes and No probabilities for both Noul questions, explicitly noting that Noul has no separate confidence;
- selected Queue, Priority, and escalation status;
- a plain-language explanation of the deterministic policy;
- serving model and token usage.

The UI remains idle until an agent deliberately runs triage. This avoids unexpected data egress and billable calls merely from opening a record.

## Routing policy

Jev supplies signals; this Apex policy selects the queue:

| Order | Condition | Assigned queue |
| --- | --- | --- |
| 1 | Risk-hold probability ≥ 0.65 or route is Risk Review | `Risk_Review` |
| 2 | Route is Reimbursements | `Reimbursements` |
| 3 | Route is Checkout Technical | `Checkout_Technical` |
| 4 | Route is Account Access | `Account_Access` |
| 5 | General issue and sentiment score ≥ 2.0 | `Priority_Care` |
| 6 | Everything else | `General_Support` |

High Priority is assigned when sentiment is at least 2.5 or immediate-attention probability is at least 0.85. Medium Priority begins at sentiment 1.25 or immediate-attention probability 0.55. Escalation is enabled at the High thresholds.

These numbers are demonstration policy. Calibrate production thresholds against labeled cases and the cost of incorrect routing.

## Included queues

Deploying the example creates these Case queues:

- Checkout Technical
- Reimbursements
- Account Access
- Risk Review
- Priority Care
- General Support

Add the appropriate agents or public groups to each Queue after deployment.

## Mocked test scenarios

All scenarios use `HttpCalloutMock`; tests never contact the live Jev service.

| Scenario | Example Case | Mocked judgment | Expected policy action |
| --- | --- | --- | --- |
| Checkout technical error | Payment fails before authorization with an error code | Checkout Technical, concerned sentiment | Assign Checkout Technical |
| Missing reimbursement | Approved reversal has not appeared | Reimbursements, frustrated sentiment | Assign Reimbursements, Medium Priority |
| Severely frustrated customer | Repeated transfers and demand for immediate help | General Support, highly distressed, high attention | Promote to Priority Care, High Priority, escalate |
| Risk hold | Withdrawal and balance unavailable during security review | High risk-hold probability | Override other routes and assign Risk Review |

Tests are implemented in `JevCaseTriageControllerTest.cls`.

## Deploy

First deploy the JevForce core and configure the `Jev_API` Named Credential as described in the [Getting Started guide](../../docs/GETTING_STARTED.md).

From the `mydevorg` workspace root:

```bash
sf project deploy start \
  --source-dir jevforce/force-app \
  --source-dir jevforce/examples/model-comparison/force-app \
  --source-dir jevforce/examples/case-triage/force-app \
  --target-org mydevorg \
  --test-level RunLocalTests \
  --wait 20
```

Or use the repository helper from the `mydevorg` workspace root:

```bash
./jevforce/scripts/deploy-mydevorg.sh
```

## Add the component to the Case page

1. Open any Case in Lightning Experience.
2. Select **Setup → Edit Page**.
3. Find **JevForce Case Triage** under Custom Components.
4. Drag it onto the Case record page.
5. Save and activate the page.
6. Confirm that the agent has:
   - Apex class access for JevForce and `JevCaseTriageController`;
   - access to the `Jev_API` External Credential principal;
   - permission to edit Case Owner, Priority, and IsEscalated;
   - permission to transfer Cases to the included queues.

## Try the live scenarios

Create Cases similar to these examples and select **Run JevForce Triage**.

To seed all four scenarios into `mydevorg` from the workspace root:

```bash
sf apex run \
  --file jevforce/examples/case-triage/scripts/seed-demo-cases.apex \
  --target-org mydevorg
```

### Checkout failure

```text
Subject: Customers cannot complete checkout
Description: Every card payment returns error PX-104 before authorization.
Several buyers retried and the checkout page still fails.
```

### Missing reimbursement

```text
Subject: Approved reimbursement has not arrived
Description: The purchase was reversed five days ago, but the credit is still
missing. I have already checked with my bank and need a status update.
```

### Highly frustrated customer

```text
Subject: Nobody will help and I am done waiting
Description: This is my fourth contact. I keep being transferred, nobody owns
the problem, and I need a person to resolve it immediately.
```

### Payment held for risk review

```text
Subject: Withdrawal placed on hold without an explanation
Description: My balance is unavailable and the withdrawal is pending while the
account is under security review. I need to know what evidence is required.
```

Live model results are probabilistic and can differ from the test fixtures. The component always displays uncertainty, and Salesforce remains responsible for the resulting action.

## Production considerations

This example is intentionally understandable rather than a complete production operating model.

- Replace direct interactive DML with your organization's preferred audit and approval controls where needed.
- Enforce the required CRUD, field-level security, sharing, and transfer policy for the entry point.
- Add bounded asynchronous retry/dead-letter handling for transient `429`, `529`, and 5xx failures.
- Persist only privacy-reviewed operational telemetry.
- Consider a human review step for low-confidence routes or high-impact actions.
- Calibrate policy thresholds and model versions against representative labeled cases.
- Keep the explicit state minimal and never add credentials or unrelated customer data.

The included `JevCaseTriageJob` remains available as a Queueable pattern for post-transaction automation. The LWC controller demonstrates an interactive callout where the callout completes before Case DML.

## Optional Models API comparison

Select **Agentforce Models API · Opus** to run the same Case state and decision criteria through Salesforce-managed Opus 4.8. The comparison displays total tokens and Apex-measured elapsed time, but never applies the generated output to the Case. Models API usage consumes Einstein Requests. See the [comparison guide](../model-comparison/README.md).
