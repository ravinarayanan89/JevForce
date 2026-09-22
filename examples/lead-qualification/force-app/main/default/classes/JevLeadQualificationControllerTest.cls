@IsTest
private class JevLeadQualificationControllerTest {
    private class QualificationMock implements HttpCalloutMock {
        private String segment;
        private Decimal intent;
        private Decimal immediateFollowUp;

        QualificationMock(String segment, Decimal intent, Decimal immediateFollowUp) {
            this.segment = segment;
            this.intent = intent;
            this.immediateFollowUp = immediateFollowUp;
        }

        public HttpResponse respond(HttpRequest request) {
            Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            Map<String, Object> questions = (Map<String, Object>) sent.get('questions');
            System.assertEquals(3, questions.size());
            System.assert(questions.containsKey('segment'));
            System.assert(questions.containsKey('intent'));
            System.assert(questions.containsKey('immediate_follow_up'));

            Map<String, Decimal> segmentProbabilities = new Map<String, Decimal>{
                'ENTERPRISE' => 0.03,
                'SMALL_BUSINESS' => 0.03,
                'PARTNERSHIPS' => 0.03,
                'NURTURE' => 0.03
            };
            segmentProbabilities.put(segment, 0.91);

            Integer nearestLevel = intent < 0.5 ? 0 :
                intent < 1.5 ? 1 : intent < 2.5 ? 2 : 3;
            Map<String, Decimal> intentProbabilities = new Map<String, Decimal>{
                '0' => 0.03,
                '1' => 0.03,
                '2' => 0.03,
                '3' => 0.03
            };
            intentProbabilities.put(String.valueOf(nearestLevel), 0.91);

            Map<String, Object> body = new Map<String, Object>{
                'model' => 'jev-1.13.0',
                'answers' => new Map<String, Object>{
                    'segment' => new Map<String, Object>{
                        'type' => 'choice',
                        'choice' => segment,
                        'confidence' => 0.89,
                        'probabilities' => segmentProbabilities
                    },
                    'intent' => new Map<String, Object>{
                        'type' => 'score',
                        'score' => intent,
                        'confidence' => 0.86,
                        'legend' => new Map<String, Object>{
                            '0' => 'Exploring',
                            '1' => 'Interested',
                            '2' => 'Active evaluation',
                            '3' => 'Sales ready'
                        },
                        'probabilities' => intentProbabilities
                    },
                    'immediate_follow_up' => new Map<String, Object>{
                        'type' => 'noul',
                        'noul' => immediateFollowUp
                    }
                },
                'usage' => new Map<String, Object>{
                    'input_tokens' => 390,
                    'output_tokens' => 58
                }
            };

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(JSON.serialize(body));
            return response;
        }
    }

    @IsTest
    static void headerIncludesLeadContext() {
        Lead leadRecord = new Lead(
            FirstName = 'Maya',
            LastName = 'Chen',
            Company = 'Northwind Systems',
            Title = 'VP Operations',
            Description = 'Evaluating a multi-region rollout.'
        );
        insert leadRecord;

        JevLeadQualificationController.LeadHeader header =
            JevLeadQualificationController.getLeadHeader(leadRecord.Id);

        System.assertEquals('Maya Chen', header.name);
        System.assertEquals(leadRecord.Company, header.company);
        System.assertEquals(leadRecord.Title, header.title);
        System.assertEquals(leadRecord.Description, header.description);
    }

    @IsTest
    static void enterpriseLeadIsHotAndCreatesFollowUp() {
        JevLeadQualificationController.QualificationResult result = runScenario(
            'ENTERPRISE', 2.8, 0.92, 'Enterprise_Sales'
        );

        System.assertEquals('Hot', result.rating);
        System.assertEquals('Sales ready', result.intentLabel);
        System.assertEquals(true, result.followUpTaskCreated);
        System.assertEquals(1, [
            SELECT count()
            FROM Task
            WHERE WhoId = :result.leadId AND Subject = '[JevForce] Immediate Lead follow-up'
        ]);
    }

    @IsTest
    static void smallBusinessLeadIsWarm() {
        JevLeadQualificationController.QualificationResult result = runScenario(
            'SMALL_BUSINESS', 1.7, 0.42, 'Small_Business_Sales'
        );
        System.assertEquals('Warm', result.rating);
        System.assertEquals(false, result.followUpTaskCreated);
    }

    @IsTest
    static void partnershipLeadRoutesToPartnerships() {
        JevLeadQualificationController.QualificationResult result = runScenario(
            'PARTNERSHIPS', 2.1, 0.56, 'Partnerships'
        );
        System.assertEquals('Partnerships', result.queueName);
        System.assertEquals('Warm', result.rating);
    }

    @IsTest
    static void earlyResearchLeadRoutesToNurture() {
        JevLeadQualificationController.QualificationResult result = runScenario(
            'NURTURE', 0.3, 0.12, 'Lead_Nurture'
        );
        System.assertEquals('Cold', result.rating);
        System.assertEquals('Exploring', result.intentLabel);
    }

    private static JevLeadQualificationController.QualificationResult runScenario(
        String segment,
        Decimal intent,
        Decimal immediateFollowUp,
        String expectedQueue
    ) {
        Lead leadRecord = new Lead(
            FirstName = 'Demo',
            LastName = segment,
            Company = 'JevForce Demo Company',
            Title = 'Operations Leader',
            Industry = 'Technology',
            AnnualRevenue = 25000000,
            NumberOfEmployees = 600,
            LeadSource = 'Web',
            Description = 'Explicit qualification context for the JevForce test.'
        );
        insert leadRecord;

        JevLeadQualificationController.queueIdOverrides = new Map<String, Id>{
            expectedQueue => UserInfo.getUserId()
        };
        Test.setMock(
            HttpCalloutMock.class,
            new QualificationMock(segment, intent, immediateFollowUp)
        );

        Test.startTest();
        JevLeadQualificationController.QualificationResult result =
            JevLeadQualificationController.analyzeLead(leadRecord.Id);
        Test.stopTest();

        Lead updated = [
            SELECT OwnerId, Rating
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals(UserInfo.getUserId(), updated.OwnerId);
        System.assertEquals(result.rating, updated.Rating);
        System.assertEquals(expectedQueue, result.queueDeveloperName);
        System.assertEquals('jev-1.13.0', result.model);
        return result;
    }
}
