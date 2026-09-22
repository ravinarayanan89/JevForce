@IsTest
private class JevCaseTriageControllerTest {
    private class ScenarioMock implements HttpCalloutMock {
        private String route;
        private Decimal sentiment;
        private Decimal riskHold;
        private Decimal immediateAttention;

        ScenarioMock(
            String route,
            Decimal sentiment,
            Decimal riskHold,
            Decimal immediateAttention
        ) {
            this.route = route;
            this.sentiment = sentiment;
            this.riskHold = riskHold;
            this.immediateAttention = immediateAttention;
        }

        public HttpResponse respond(HttpRequest request) {
            Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            Map<String, Object> questions = (Map<String, Object>) sent.get('questions');
            System.assertEquals(4, questions.size());
            System.assert(questions.containsKey('route'));
            System.assert(questions.containsKey('sentiment'));
            System.assert(questions.containsKey('risk_hold'));
            System.assert(questions.containsKey('immediate_attention'));

            Map<String, Decimal> routeProbabilities = new Map<String, Decimal>{
                'CHECKOUT_TECHNICAL' => 0.025,
                'REIMBURSEMENTS' => 0.025,
                'ACCOUNT_ACCESS' => 0.025,
                'RISK_REVIEW' => 0.025,
                'GENERAL_SUPPORT' => 0.025
            };
            routeProbabilities.put(route, 0.90);

            Integer nearestLevel = sentiment < 0.5 ? 0 :
                sentiment < 1.5 ? 1 : sentiment < 2.5 ? 2 : 3;
            Map<String, Decimal> sentimentProbabilities = new Map<String, Decimal>{
                '0' => 0.02,
                '1' => 0.03,
                '2' => 0.03,
                '3' => 0.02
            };
            sentimentProbabilities.put(String.valueOf(nearestLevel), 0.90);

            Map<String, Object> responseBody = new Map<String, Object>{
                'model' => 'jev-1.13.0',
                'answers' => new Map<String, Object>{
                    'route' => new Map<String, Object>{
                        'type' => 'choice',
                        'choice' => route,
                        'confidence' => 0.88,
                        'probabilities' => routeProbabilities
                    },
                    'sentiment' => new Map<String, Object>{
                        'type' => 'score',
                        'score' => sentiment,
                        'confidence' => 0.84,
                        'legend' => new Map<String, Object>{
                            '0' => 'Calm or neutral',
                            '1' => 'Concerned or disappointed',
                            '2' => 'Frustrated or angry',
                            '3' => 'Highly distressed'
                        },
                        'probabilities' => sentimentProbabilities
                    },
                    'risk_hold' => new Map<String, Object>{
                        'type' => 'noul',
                        'noul' => riskHold
                    },
                    'immediate_attention' => new Map<String, Object>{
                        'type' => 'noul',
                        'noul' => immediateAttention
                    }
                },
                'usage' => new Map<String, Object>{
                    'input_tokens' => 460,
                    'output_tokens' => 72
                }
            };

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(JSON.serialize(responseBody));
            return response;
        }
    }

    @IsTest
    static void caseHeaderIncludesDescriptionOnInitialLoad() {
        Case caseRecord = new Case(
            Subject = 'Reimbursement still missing',
            Description = 'The approved credit has not reached my account.',
            Origin = 'Web',
            Status = 'New'
        );
        insert caseRecord;

        Test.startTest();
        JevCaseTriageController.CaseHeader header =
            JevCaseTriageController.getCaseHeader(caseRecord.Id);
        Test.stopTest();

        System.assertEquals(caseRecord.Subject, header.subject);
        System.assertEquals(caseRecord.Description, header.description);
        System.assertNotEquals(null, header.caseNumber);
    }

    @IsTest
    static void checkoutTechnicalErrorRoutesToTechnicalQueue() {
        JevCaseTriageController.TriageResult result = runScenario(
            'Card payment fails at checkout with error code PX-104',
            'Every checkout attempt returns a technical error before authorization.',
            'CHECKOUT_TECHNICAL', 1.1, 0.04, 0.42,
            'Checkout_Technical'
        );

        System.assertEquals('Checkout Technical', result.queueName);
        System.assertEquals('Concerned', result.sentimentLabel);
        System.assertEquals('Low', result.priority);
        System.assertEquals(false, result.escalated);
    }

    @IsTest
    static void reimbursementCaseRoutesToMoneyMovementSpecialists() {
        JevCaseTriageController.TriageResult result = runScenario(
            'Approved reimbursement has not arrived',
            'The purchase was reversed five days ago, but the credit is still missing.',
            'REIMBURSEMENTS', 1.8, 0.08, 0.63,
            'Reimbursements'
        );

        System.assertEquals('Reimbursements', result.queueName);
        System.assertEquals('Frustrated', result.sentimentLabel);
        System.assertEquals('Medium', result.priority);
    }

    @IsTest
    static void highlyFrustratedGeneralCasePromotesToPriorityCare() {
        JevCaseTriageController.TriageResult result = runScenario(
            'Nobody will help and I am done waiting',
            'This is my fourth contact. I keep being transferred and need a person now.',
            'GENERAL_SUPPORT', 2.9, 0.05, 0.94,
            'Priority_Care'
        );

        System.assertEquals('Priority Care', result.queueName);
        System.assertEquals('Highly distressed', result.sentimentLabel);
        System.assertEquals('High', result.priority);
        System.assertEquals(true, result.escalated);
        System.assert(result.policyExplanation.contains('frustration'));
    }

    @IsTest
    static void riskHoldOverridesOtherRoutingSignals() {
        JevCaseTriageController.TriageResult result = runScenario(
            'Withdrawal placed on hold without an explanation',
            'My balance is unavailable while the account is under security review.',
            'GENERAL_SUPPORT', 2.1, 0.97, 0.79,
            'Risk_Review'
        );

        System.assertEquals('Risk Review', result.queueName);
        System.assertEquals(0.97, result.riskHoldProbability);
        System.assert(result.policyExplanation.contains('risk-hold'));
    }

    private static JevCaseTriageController.TriageResult runScenario(
        String subject,
        String description,
        String route,
        Decimal sentiment,
        Decimal riskHold,
        Decimal immediateAttention,
        String expectedQueue
    ) {
        Case caseRecord = new Case(
            Subject = subject,
            Description = description,
            Origin = 'Web',
            Status = 'New',
            Priority = 'Low'
        );
        insert caseRecord;

        JevCaseTriageController.queueIdOverrides = new Map<String, Id>{
            expectedQueue => UserInfo.getUserId()
        };
        Test.setMock(
            HttpCalloutMock.class,
            new ScenarioMock(route, sentiment, riskHold, immediateAttention)
        );

        Test.startTest();
        JevCaseTriageController.TriageResult result =
            JevCaseTriageController.analyzeCase(caseRecord.Id);
        Test.stopTest();

        Case updated = [
            SELECT OwnerId, Priority, IsEscalated
            FROM Case
            WHERE Id = :caseRecord.Id
        ];
        System.assertEquals(UserInfo.getUserId(), updated.OwnerId);
        System.assertEquals(result.priority, updated.Priority);
        System.assertEquals(result.escalated, updated.IsEscalated);
        System.assertEquals(expectedQueue, result.queueDeveloperName);
        System.assertEquals('jev-1.13.0', result.model);
        return result;
    }
}
