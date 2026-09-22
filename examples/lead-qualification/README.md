# Live Lead Qualification

This example places **JevForce Lead Qualification** on a Lead record page. It demonstrates the same boundary as Case Triage in a sales scenario:

> Salesforce supplies explicit Lead context → Jev returns structured judgments → Salesforce applies routing and follow-up policy.

## Live judgments

One Jev request evaluates three independent questions against the same Lead state:

| Primitive | Judgment | Returned uncertainty |
| --- | --- | --- |
| Choice | Enterprise, Small Business, Partnerships, or Nurture | All segment probabilities and confidence |
| Score | Buying intent from Exploring through Sales Ready | Full ordered distribution, weighted score, and confidence |
| Noul | Whether personal follow-up is warranted within one business hour | Probability of yes |

## Salesforce-owned policy

- Choice maps deterministically to one of four Lead queues.
- Rating is `Hot` when intent is at least `2.5` or immediate follow-up is at least `0.80`.
- Rating is `Warm` when intent is at least `1.25` or immediate follow-up is at least `0.50`; otherwise it is `Cold`.
- At `0.80` immediate-follow-up probability, Salesforce creates one open high-priority Task for the current user. Re-running qualification does not create duplicate open Tasks.

These thresholds belong to the example application, not JevForce.

## Deploy

From the `mydevorg` workspace root:

```bash
sf project deploy start \
  --source-dir jevforce/force-app \
  --source-dir jevforce/examples/model-comparison/force-app \
  --source-dir jevforce/examples/lead-qualification/force-app \
  --target-org mydevorg \
  --test-level RunSpecifiedTests \
  --tests JevForceTest \
  --tests JevLeadQualificationControllerTest \
  --wait 20
```

## Seed four demo Leads

```bash
sf apex run \
  --file jevforce/examples/lead-qualification/scripts/seed-demo-leads.apex \
  --target-org mydevorg
```

The scenarios cover Enterprise, Small Business, Partnerships, and Nurture. All records are initially owned by the user who runs the script.

## Add the component to the Lead page

1. Open a Lead in Lightning Experience.
2. Select **Setup → Edit Page**.
3. Drag **JevForce Lead Qualification** from Custom Components onto the page.
4. Save and activate the page.
5. Confirm that the user has Apex class access, External Credential principal access, Lead transfer permission, Rating edit access, and Task create permission.

The component waits for an explicit click before sending Lead data or making a billable call.

## Optional Models API comparison

Select **Agentforce Models API · Opus** to run the same Lead state and decision criteria through Salesforce-managed Opus 4.8. The comparison displays total tokens and Apex-measured elapsed time, but never assigns the Lead, changes Rating, or creates a Task. Models API usage consumes Einstein Requests. See the [comparison guide](../model-comparison/README.md).
