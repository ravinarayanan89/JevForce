public with sharing class JevCaseTriageController {
    private static final Decimal RISK_QUEUE_THRESHOLD = 0.65;
    private static final Decimal PRIORITY_CARE_SENTIMENT_THRESHOLD = 2.0;
    private static final Decimal ESCALATION_THRESHOLD = 0.85;

    @TestVisible
    private static Map<String, Id> queueIdOverrides;

    @AuraEnabled(cacheable=true)
    public static CaseHeader getCaseHeader(Id caseId) {
        validateCaseId(caseId);
        Case caseRecord = [
            SELECT CaseNumber, Subject, Description, Owner.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        CaseHeader header = new CaseHeader();
        header.caseNumber = caseRecord.CaseNumber;
        header.subject = caseRecord.Subject;
        header.description = caseRecord.Description;
        header.ownerName = caseRecord.Owner.Name;
        return header;
    }

    @AuraEnabled
    public static JevModelsApiBenchmark.Result benchmarkWithClaude(Id caseId) {
        validateCaseId(caseId);
        Case caseRecord = [
            SELECT CaseNumber, Subject, Description, Status, Origin, Priority, Owner.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        Map<String, Object> state = new Map<String, Object>{
            'caseNumber' => caseRecord.CaseNumber,
            'subject' => caseRecord.Subject,
            'description' => caseRecord.Description,
            'status' => caseRecord.Status,
            'origin' => caseRecord.Origin,
            'currentPriority' => caseRecord.Priority,
            'currentOwner' => caseRecord.Owner.Name
        };
        Map<String, Object> questions = new Map<String, Object>{
            'route' => new Map<String, Object>{
                'type' => 'choice',
                'instructions' => 'Which specialist team should own this payment-services support case?',
                'criteria' => new Map<String, String>{
                    'CHECKOUT_TECHNICAL' => 'Checkout failures, payment-page errors, integration faults, authorization errors, or transactions that cannot complete',
                    'REIMBURSEMENTS' => 'Refunds, reimbursements, reversals, duplicate charges, disputes about money being returned, or missing credits',
                    'ACCOUNT_ACCESS' => 'Login, identity verification, profile access, account recovery, or credential problems',
                    'RISK_REVIEW' => 'Payments, withdrawals, balances, or accounts restricted or held for fraud, compliance, security, or risk review',
                    'GENERAL_SUPPORT' => 'General questions or issues that do not clearly belong to another specialist team'
                }
            },
            'sentiment' => new Map<String, Object>{
                'type' => 'score',
                'instructions' => 'Assess the customer sentiment and emotional intensity in the case.',
                'criteria' => new List<String>{
                    'Calm or neutral',
                    'Concerned or disappointed',
                    'Frustrated or angry',
                    'Highly distressed, threatening departure, or demanding immediate intervention'
                }
            },
            'risk_hold' => new Map<String, Object>{
                'type' => 'noul',
                'instructions' => 'Does the case indicate that funds, a payment, a withdrawal, or an account is being held or restricted because of risk, fraud, compliance, or security review?'
            },
            'immediate_attention' => new Map<String, Object>{
                'type' => 'noul',
                'instructions' => 'Does this case warrant immediate human attention because of customer impact, emotional intensity, repeated failed support, or time sensitivity?'
            }
        };
        String prompt =
            'Evaluate the following state against every question. Return only compact JSON. ' +
            'For Choice include choice and probabilities for every option. For Score include ' +
            'score, confidence, and probabilities for every level. For Noul include a yes ' +
            'probability. Do not include explanation or markdown.\n' +
            JSON.serialize(new Map<String, Object>{ 'state' => state, 'questions' => questions });
        try {
            return JevModelsApiBenchmark.run(prompt);
        } catch (Exception error) {
            throw new AuraHandledException(error.getMessage());
        }
    }

    @AuraEnabled
    public static TriageResult analyzeCase(Id caseId) {
        validateCaseId(caseId);

        Case caseRecord = [
            SELECT Id, CaseNumber, Subject, Description, Status, Origin, Priority,
                   IsEscalated, OwnerId, Owner.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        JevState state = new JevState()
            .put('caseNumber', caseRecord.CaseNumber)
            .put('subject', caseRecord.Subject)
            .put('description', caseRecord.Description)
            .put('status', caseRecord.Status)
            .put('origin', caseRecord.Origin)
            .put('currentPriority', caseRecord.Priority)
            .put('currentOwner', caseRecord.Owner.Name);

        JevRequest request = new JevRequest(state)
            .addChoice(
                'route',
                'Which specialist team should own this payment-services support case?',
                new Map<String, String>{
                    'CHECKOUT_TECHNICAL' =>
                        'Checkout failures, payment-page errors, integration faults, authorization errors, or transactions that cannot complete',
                    'REIMBURSEMENTS' =>
                        'Refunds, reimbursements, reversals, duplicate charges, disputes about money being returned, or missing credits',
                    'ACCOUNT_ACCESS' =>
                        'Login, identity verification, profile access, account recovery, or credential problems',
                    'RISK_REVIEW' =>
                        'Payments, withdrawals, balances, or accounts restricted or held for fraud, compliance, security, or risk review',
                    'GENERAL_SUPPORT' =>
                        'General questions or issues that do not clearly belong to another specialist team'
                }
            )
            .addScore(
                'sentiment',
                'Assess the customer sentiment and emotional intensity in the case.',
                new List<String>{
                    'Calm or neutral',
                    'Concerned or disappointed',
                    'Frustrated or angry',
                    'Highly distressed, threatening departure, or demanding immediate intervention'
                }
            )
            .addNoul(
                'risk_hold',
                'Does the case indicate that funds, a payment, a withdrawal, or an account is being held or restricted because of risk, fraud, compliance, or security review?'
            )
            .addNoul(
                'immediate_attention',
                'Does this case warrant immediate human attention because of customer impact, emotional intensity, repeated failed support, or time sensitivity?'
            );

        JevResponse judgments;
        Long jevStartedAt = Datetime.now().getTime();
        try {
            judgments = JevForce.execute(request);
        } catch (JevException error) {
            throw new AuraHandledException(error.getMessage());
        }
        Long jevElapsedMilliseconds = Datetime.now().getTime() - jevStartedAt;

        JevChoiceResult routing = judgments.choice('route');
        JevScoreResult sentiment = judgments.score('sentiment');
        JevNoulResult riskHold = judgments.noul('risk_hold');
        JevNoulResult immediateAttention = judgments.noul('immediate_attention');

        String queueDeveloperName = chooseQueue(
            routing.choice,
            sentiment.score,
            riskHold.probability
        );
        Id targetOwnerId = resolveQueueId(queueDeveloperName);
        if (targetOwnerId == null) {
            throw new AuraHandledException(
                'The queue ' + queueDeveloperName + ' is not configured for Case ownership.'
            );
        }

        String priority = choosePriority(sentiment.score, immediateAttention.probability);
        Boolean escalated = sentiment.score >= 2.5 ||
            immediateAttention.probability >= ESCALATION_THRESHOLD;

        caseRecord.OwnerId = targetOwnerId;
        caseRecord.Priority = priority;
        caseRecord.IsEscalated = escalated;
        try {
            update caseRecord;
        } catch (DmlException error) {
            throw new AuraHandledException(
                'Jev completed the analysis, but Salesforce could not update the Case. ' +
                'Verify Case edit access and queue membership.'
            );
        }

        TriageResult result = new TriageResult();
        result.caseId = caseRecord.Id;
        result.caseNumber = caseRecord.CaseNumber;
        result.route = routing.choice;
        result.routeConfidence = routing.confidence;
        result.routeProbabilities = routing.probabilities;
        result.sentimentScore = sentiment.score;
        result.sentimentConfidence = sentiment.confidence;
        result.sentimentLabel = sentimentLabel(sentiment.score);
        result.sentimentProbabilities = sentiment.probabilities;
        result.riskHoldProbability = riskHold.probability;
        result.immediateAttentionProbability = immediateAttention.probability;
        result.previousOwner = caseRecord.Owner.Name;
        result.queueDeveloperName = queueDeveloperName;
        result.queueName = queueLabel(queueDeveloperName);
        result.ownerId = targetOwnerId;
        result.priority = priority;
        result.escalated = escalated;
        result.model = judgments.model;
        result.inputTokens = judgments.inputTokens;
        result.outputTokens = judgments.outputTokens;
        result.totalTokens = judgments.inputTokens + judgments.outputTokens;
        result.elapsedMilliseconds = jevElapsedMilliseconds;
        result.policyExplanation = policyExplanation(
            routing.choice,
            sentiment.score,
            riskHold.probability,
            queueDeveloperName
        );
        return result;
    }

    private static String chooseQueue(String route, Decimal sentiment, Decimal riskHold) {
        if (riskHold >= RISK_QUEUE_THRESHOLD || route == 'RISK_REVIEW') {
            return 'Risk_Review';
        }
        if (route == 'REIMBURSEMENTS') return 'Reimbursements';
        if (route == 'CHECKOUT_TECHNICAL') return 'Checkout_Technical';
        if (route == 'ACCOUNT_ACCESS') return 'Account_Access';
        if (sentiment >= PRIORITY_CARE_SENTIMENT_THRESHOLD) return 'Priority_Care';
        return 'General_Support';
    }

    private static void validateCaseId(Id caseId) {
        if (caseId == null || caseId.getSObjectType() != Case.SObjectType) {
            throw new AuraHandledException('Select a valid Case before running Jev triage.');
        }
    }

    private static String choosePriority(Decimal sentiment, Decimal immediateAttention) {
        if (sentiment >= 2.5 || immediateAttention >= ESCALATION_THRESHOLD) return 'High';
        if (sentiment >= 1.25 || immediateAttention >= 0.55) return 'Medium';
        return 'Low';
    }

    private static Id resolveQueueId(String developerName) {
        if (Test.isRunningTest() && queueIdOverrides != null &&
            queueIdOverrides.containsKey(developerName)) {
            return queueIdOverrides.get(developerName);
        }
        List<Group> matches = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName = :developerName
            LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0].Id;
    }

    private static String sentimentLabel(Decimal score) {
        if (score >= 2.5) return 'Highly distressed';
        if (score >= 1.5) return 'Frustrated';
        if (score >= 0.5) return 'Concerned';
        return 'Calm';
    }

    private static String queueLabel(String developerName) {
        return developerName.replace('_', ' ');
    }

    private static String policyExplanation(
        String route,
        Decimal sentiment,
        Decimal riskHold,
        String queueDeveloperName
    ) {
        if (riskHold >= RISK_QUEUE_THRESHOLD || route == 'RISK_REVIEW') {
            return 'Salesforce policy prioritized the risk-hold signal and assigned Risk Review.';
        }
        if (route == 'GENERAL_SUPPORT' && sentiment >= PRIORITY_CARE_SENTIMENT_THRESHOLD) {
            return 'The issue was general, but elevated frustration triggered Priority Care.';
        }
        return 'Salesforce policy mapped the Jev issue classification to ' +
            queueLabel(queueDeveloperName) + '.';
    }

    public class TriageResult {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String route { get; set; }
        @AuraEnabled public Decimal routeConfidence { get; set; }
        @AuraEnabled public Map<String, Decimal> routeProbabilities { get; set; }
        @AuraEnabled public Decimal sentimentScore { get; set; }
        @AuraEnabled public Decimal sentimentConfidence { get; set; }
        @AuraEnabled public String sentimentLabel { get; set; }
        @AuraEnabled public Map<String, Decimal> sentimentProbabilities { get; set; }
        @AuraEnabled public Decimal riskHoldProbability { get; set; }
        @AuraEnabled public Decimal immediateAttentionProbability { get; set; }
        @AuraEnabled public String previousOwner { get; set; }
        @AuraEnabled public String queueDeveloperName { get; set; }
        @AuraEnabled public String queueName { get; set; }
        @AuraEnabled public Id ownerId { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public Boolean escalated { get; set; }
        @AuraEnabled public String model { get; set; }
        @AuraEnabled public Integer inputTokens { get; set; }
        @AuraEnabled public Integer outputTokens { get; set; }
        @AuraEnabled public Integer totalTokens { get; set; }
        @AuraEnabled public Long elapsedMilliseconds { get; set; }
        @AuraEnabled public String policyExplanation { get; set; }
    }

    public class CaseHeader {
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String ownerName { get; set; }
    }
}
