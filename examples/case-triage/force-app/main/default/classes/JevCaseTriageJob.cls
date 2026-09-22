public with sharing class JevCaseTriageJob implements Queueable, Database.AllowsCallouts {
    private Id caseId;
    private String customerTier;
    private Integer previousCases;

    public JevCaseTriageJob(Id caseId, String customerTier, Integer previousCases) {
        this.caseId = caseId;
        this.customerTier = customerTier;
        this.previousCases = previousCases;
    }

    public void execute(QueueableContext context) {
        Case caseRecord = [
            SELECT Id, Subject, Description, Priority, IsEscalated, OwnerId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        JevState state = new JevState()
            .put('subject', caseRecord.Subject)
            .put('description', caseRecord.Description)
            .put('currentPriority', caseRecord.Priority)
            .put('customerTier', customerTier)
            .put('previousCases', previousCases);

        JevRequest request = new JevRequest(state)
            .addChoice(
                'routing',
                'Which support team best matches this case?',
                new Map<String, String>{
                    'BILLING' => 'Charges, refunds, duplicate payments and invoices',
                    'FRAUD' => 'Unauthorized transactions or suspicious activity',
                    'TECHNICAL' => 'Technical product problems',
                    'ACCOUNT' => 'Login, access and account management'
                }
            )
            .addScore(
                'urgency',
                'Assess the urgency of this customer issue.',
                new List<String>{ 'Routine', 'Needs Attention', 'Urgent', 'Critical' }
            )
            .addNoul(
                'escalation',
                'Does the evidence suggest this case warrants immediate human escalation?'
            );

        // One callout evaluates all three independent judgments against the same state.
        JevResponse judgments = JevForce.execute(request);

        // Everything below is deterministic Salesforce-owned policy.
        applyRoutingPolicy(caseRecord, judgments.choice('routing').choice);
        applyPriorityPolicy(caseRecord, judgments.score('urgency').score);
        if (judgments.noul('escalation').probability >= 0.85) {
            caseRecord.IsEscalated = true;
        }
        update caseRecord;
    }

    private static void applyRoutingPolicy(Case caseRecord, String route) {
        Map<String, String> queueByChoice = new Map<String, String>{
            'BILLING' => 'Reimbursements',
            'FRAUD' => 'Risk_Review',
            'TECHNICAL' => 'Checkout_Technical',
            'ACCOUNT' => 'Account_Access'
        };
        String queueDeveloperName = queueByChoice.get(route);
        if (queueDeveloperName == null) return;

        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName = :queueDeveloperName
            LIMIT 1
        ];
        if (!queues.isEmpty()) caseRecord.OwnerId = queues[0].Id;
    }

    private static void applyPriorityPolicy(Case caseRecord, Decimal score) {
        if (score >= 2.5) caseRecord.Priority = 'High';
        else if (score >= 1.5) caseRecord.Priority = 'Medium';
        else caseRecord.Priority = 'Low';
    }
}
