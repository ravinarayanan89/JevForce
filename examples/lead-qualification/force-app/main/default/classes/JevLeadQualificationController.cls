public with sharing class JevLeadQualificationController {
    private static final Decimal HOT_INTENT_THRESHOLD = 2.5;
    private static final Decimal WARM_INTENT_THRESHOLD = 1.25;
    private static final Decimal IMMEDIATE_FOLLOW_UP_THRESHOLD = 0.80;
    private static final Decimal WARM_FOLLOW_UP_THRESHOLD = 0.50;
    private static final String FOLLOW_UP_SUBJECT = '[JevForce] Immediate Lead follow-up';

    @TestVisible
    private static Map<String, Id> queueIdOverrides;

    @AuraEnabled(cacheable=true)
    public static LeadHeader getLeadHeader(Id leadId) {
        validateLeadId(leadId);
        Lead leadRecord = [
            SELECT Name, Company, Title, Description, Owner.Name
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        LeadHeader header = new LeadHeader();
        header.name = leadRecord.Name;
        header.company = leadRecord.Company;
        header.title = leadRecord.Title;
        header.description = leadRecord.Description;
        header.ownerName = leadRecord.Owner.Name;
        return header;
    }

    @AuraEnabled
    public static JevModelsApiBenchmark.Result benchmarkWithClaude(Id leadId) {
        validateLeadId(leadId);
        Lead leadRecord = [
            SELECT Name, Company, Title, Industry, AnnualRevenue, NumberOfEmployees,
                   LeadSource, Status, Description
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        Map<String, Object> state = new Map<String, Object>{
            'name' => leadRecord.Name,
            'company' => leadRecord.Company,
            'title' => leadRecord.Title,
            'industry' => leadRecord.Industry,
            'annualRevenue' => leadRecord.AnnualRevenue,
            'numberOfEmployees' => leadRecord.NumberOfEmployees,
            'leadSource' => leadRecord.LeadSource,
            'status' => leadRecord.Status,
            'description' => leadRecord.Description
        };
        Map<String, Object> questions = new Map<String, Object>{
            'segment' => new Map<String, Object>{
                'type' => 'choice',
                'instructions' => 'Which sales motion best matches this Lead?',
                'criteria' => new Map<String, String>{
                    'ENTERPRISE' => 'Large or complex organizations with multi-team rollout, procurement, security, compliance, or substantial scale',
                    'SMALL_BUSINESS' => 'Smaller organizations seeking a straightforward near-term purchase with limited implementation complexity',
                    'PARTNERSHIPS' => 'Technology, referral, channel, reseller, integration, or strategic partnership opportunities',
                    'NURTURE' => 'Early research, unclear fit, missing budget or timeline, education, or low evidence of an active purchase'
                }
            },
            'intent' => new Map<String, Object>{
                'type' => 'score',
                'instructions' => 'Assess the Lead buying intent from the supplied evidence.',
                'criteria' => new List<String>{
                    'Exploring with no clear commercial intent',
                    'Interested but missing a defined project or timeline',
                    'Active evaluation with a plausible need and timeframe',
                    'Ready for direct sales engagement with urgency, authority, or a concrete buying process'
                }
            },
            'immediate_follow_up' => new Map<String, Object>{
                'type' => 'noul',
                'instructions' => 'Does this Lead warrant personal follow-up within one business hour based on urgency, commercial value, authority, or a time-sensitive buying event?'
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
    public static QualificationResult analyzeLead(Id leadId) {
        validateLeadId(leadId);
        Lead leadRecord = [
            SELECT Id, Name, Company, Title, Industry, AnnualRevenue,
                   NumberOfEmployees, LeadSource, Status, Rating, Description,
                   OwnerId, Owner.Name
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        JevState state = new JevState()
            .put('name', leadRecord.Name)
            .put('company', leadRecord.Company)
            .put('title', leadRecord.Title)
            .put('industry', leadRecord.Industry)
            .put('annualRevenue', leadRecord.AnnualRevenue)
            .put('numberOfEmployees', leadRecord.NumberOfEmployees)
            .put('leadSource', leadRecord.LeadSource)
            .put('status', leadRecord.Status)
            .put('description', leadRecord.Description);

        JevRequest request = new JevRequest(state)
            .addChoice(
                'segment',
                'Which sales motion best matches this Lead?',
                new Map<String, String>{
                    'ENTERPRISE' =>
                        'Large or complex organizations with multi-team rollout, procurement, security, compliance, or substantial scale',
                    'SMALL_BUSINESS' =>
                        'Smaller organizations seeking a straightforward near-term purchase with limited implementation complexity',
                    'PARTNERSHIPS' =>
                        'Technology, referral, channel, reseller, integration, or strategic partnership opportunities',
                    'NURTURE' =>
                        'Early research, unclear fit, missing budget or timeline, education, or low evidence of an active purchase'
                }
            )
            .addScore(
                'intent',
                'Assess the Lead buying intent from the supplied evidence.',
                new List<String>{
                    'Exploring with no clear commercial intent',
                    'Interested but missing a defined project or timeline',
                    'Active evaluation with a plausible need and timeframe',
                    'Ready for direct sales engagement with urgency, authority, or a concrete buying process'
                }
            )
            .addNoul(
                'immediate_follow_up',
                'Does this Lead warrant personal follow-up within one business hour based on urgency, commercial value, authority, or a time-sensitive buying event?'
            );

        JevResponse judgments;
        Long jevStartedAt = Datetime.now().getTime();
        try {
            judgments = JevForce.execute(request);
        } catch (JevException error) {
            throw new AuraHandledException(error.getMessage());
        }
        Long jevElapsedMilliseconds = Datetime.now().getTime() - jevStartedAt;

        JevChoiceResult segment = judgments.choice('segment');
        JevScoreResult intent = judgments.score('intent');
        JevNoulResult immediateFollowUp = judgments.noul('immediate_follow_up');
        String queueDeveloperName = queueFor(segment.choice);
        Id targetOwnerId = resolveQueueId(queueDeveloperName);
        if (targetOwnerId == null) {
            throw new AuraHandledException(
                'The Lead queue ' + queueDeveloperName + ' is not configured.'
            );
        }

        String previousOwner = leadRecord.Owner.Name;
        String rating = chooseRating(intent.score, immediateFollowUp.probability);
        leadRecord.OwnerId = targetOwnerId;
        leadRecord.Rating = rating;

        Boolean taskCreated = false;
        try {
            update leadRecord;
            if (immediateFollowUp.probability >= IMMEDIATE_FOLLOW_UP_THRESHOLD &&
                !hasOpenFollowUpTask(leadRecord.Id)) {
                insert new Task(
                    WhoId = leadRecord.Id,
                    OwnerId = UserInfo.getUserId(),
                    Subject = FOLLOW_UP_SUBJECT,
                    Status = 'Not Started',
                    Priority = 'High',
                    ActivityDate = Date.today(),
                    Description = 'Created by deterministic Salesforce policy after Jev Lead qualification.'
                );
                taskCreated = true;
            }
        } catch (DmlException error) {
            throw new AuraHandledException(
                'Jev completed the qualification, but Salesforce could not apply the Lead policy. ' +
                'Verify Lead transfer, Rating, and Task permissions.'
            );
        }

        QualificationResult result = new QualificationResult();
        result.leadId = leadRecord.Id;
        result.segment = segment.choice;
        result.segmentConfidence = segment.confidence;
        result.segmentProbabilities = segment.probabilities;
        result.intentScore = intent.score;
        result.intentConfidence = intent.confidence;
        result.intentProbabilities = intent.probabilities;
        result.intentLabel = intentLabel(intent.score);
        result.immediateFollowUpProbability = immediateFollowUp.probability;
        result.previousOwner = previousOwner;
        result.queueDeveloperName = queueDeveloperName;
        result.queueName = queueDeveloperName.replace('_', ' ');
        result.ownerId = targetOwnerId;
        result.rating = rating;
        result.followUpTaskCreated = taskCreated;
        result.model = judgments.model;
        result.inputTokens = judgments.inputTokens;
        result.outputTokens = judgments.outputTokens;
        result.totalTokens = judgments.inputTokens + judgments.outputTokens;
        result.elapsedMilliseconds = jevElapsedMilliseconds;
        result.policyExplanation = policyExplanation(
            segment.choice,
            intent.score,
            immediateFollowUp.probability,
            queueDeveloperName,
            rating
        );
        return result;
    }

    private static void validateLeadId(Id leadId) {
        if (leadId == null || leadId.getSObjectType() != Lead.SObjectType) {
            throw new AuraHandledException('Select a valid Lead before running Jev qualification.');
        }
    }

    private static String queueFor(String segment) {
        if (segment == 'ENTERPRISE') return 'Enterprise_Sales';
        if (segment == 'SMALL_BUSINESS') return 'Small_Business_Sales';
        if (segment == 'PARTNERSHIPS') return 'Partnerships';
        return 'Lead_Nurture';
    }

    private static String chooseRating(Decimal intent, Decimal immediateFollowUp) {
        if (intent >= HOT_INTENT_THRESHOLD ||
            immediateFollowUp >= IMMEDIATE_FOLLOW_UP_THRESHOLD) return 'Hot';
        if (intent >= WARM_INTENT_THRESHOLD ||
            immediateFollowUp >= WARM_FOLLOW_UP_THRESHOLD) return 'Warm';
        return 'Cold';
    }

    private static String intentLabel(Decimal score) {
        if (score >= 2.5) return 'Sales ready';
        if (score >= 1.5) return 'Active evaluation';
        if (score >= 0.5) return 'Early interest';
        return 'Exploring';
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

    private static Boolean hasOpenFollowUpTask(Id leadId) {
        return ![
            SELECT Id
            FROM Task
            WHERE WhoId = :leadId AND Subject = :FOLLOW_UP_SUBJECT AND IsClosed = false
            LIMIT 1
        ].isEmpty();
    }

    private static String policyExplanation(
        String segment,
        Decimal intent,
        Decimal followUpProbability,
        String queueDeveloperName,
        String rating
    ) {
        String explanation = 'Salesforce mapped ' + segment.replace('_', ' ') +
            ' to ' + queueDeveloperName.replace('_', ' ') +
            ' and set Rating to ' + rating + '.';
        if (followUpProbability >= IMMEDIATE_FOLLOW_UP_THRESHOLD) {
            explanation += ' The immediate-follow-up threshold also required an open high-priority Task.';
        } else {
            explanation += ' No immediate Task was required by the current policy.';
        }
        return explanation;
    }

    public class LeadHeader {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String company { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String ownerName { get; set; }
    }

    public class QualificationResult {
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public String segment { get; set; }
        @AuraEnabled public Decimal segmentConfidence { get; set; }
        @AuraEnabled public Map<String, Decimal> segmentProbabilities { get; set; }
        @AuraEnabled public Decimal intentScore { get; set; }
        @AuraEnabled public Decimal intentConfidence { get; set; }
        @AuraEnabled public Map<String, Decimal> intentProbabilities { get; set; }
        @AuraEnabled public String intentLabel { get; set; }
        @AuraEnabled public Decimal immediateFollowUpProbability { get; set; }
        @AuraEnabled public String previousOwner { get; set; }
        @AuraEnabled public String queueDeveloperName { get; set; }
        @AuraEnabled public String queueName { get; set; }
        @AuraEnabled public Id ownerId { get; set; }
        @AuraEnabled public String rating { get; set; }
        @AuraEnabled public Boolean followUpTaskCreated { get; set; }
        @AuraEnabled public String model { get; set; }
        @AuraEnabled public Integer inputTokens { get; set; }
        @AuraEnabled public Integer outputTokens { get; set; }
        @AuraEnabled public Integer totalTokens { get; set; }
        @AuraEnabled public Long elapsedMilliseconds { get; set; }
        @AuraEnabled public String policyExplanation { get; set; }
    }
}
