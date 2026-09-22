@IsTest
private class JevCaseTriageJobTest {
    private static Integer callCount = 0;

    private class TriageMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            callCount++;
            Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            Map<String, Object> questions = (Map<String, Object>) sent.get('questions');
            System.assertEquals(3, questions.size(), 'Triage should use one three-question call.');

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                '{"model":"jev-1.13.0","answers":{' +
                '"routing":{"type":"choice","choice":"BILLING","confidence":0.9,' +
                    '"probabilities":{"BILLING":0.9,"FRAUD":0.04,"TECHNICAL":0.03,"ACCOUNT":0.03}},' +
                '"urgency":{"type":"score","score":2.8,"confidence":0.88,' +
                    '"legend":{"0":"Routine","1":"Needs Attention","2":"Urgent","3":"Critical"},' +
                    '"probabilities":{"0":0.0,"1":0.02,"2":0.16,"3":0.82}},' +
                '"escalation":{"type":"noul","noul":0.91}},' +
                '"usage":{"input_tokens":400,"output_tokens":60}}'
            );
            return response;
        }
    }

    @IsTest
    static void appliesSalesforceOwnedPolicyAsynchronously() {
        Case caseRecord = new Case(
            Subject = 'Charged twice and nobody is helping me',
            Description = 'Third contact; duplicate transaction; needs immediate resolution.',
            Origin = 'Web',
            Status = 'New',
            Priority = 'Low'
        );
        insert caseRecord;
        Test.setMock(HttpCalloutMock.class, new TriageMock());

        Test.startTest();
        System.enqueueJob(new JevCaseTriageJob(caseRecord.Id, 'Platinum', 3));
        Test.stopTest();

        Case updated = [SELECT Priority, IsEscalated FROM Case WHERE Id = :caseRecord.Id];
        System.assertEquals('High', updated.Priority);
        System.assertEquals(true, updated.IsEscalated);
        System.assertEquals(1, callCount);
    }
}
