@IsTest
private class JevForceTest {
    private static final String USAGE = '"usage":{"input_tokens":100,"output_tokens":20}';

    @IsTest
    static void choiceSuccessUsesOfficialWireContract() {
        Test.setMock(HttpCalloutMock.class, new JevHttpMock(200,
            '{"model":"jev-1.13.0","answers":{"result":{' +
            '"type":"choice","choice":"BILLING","confidence":0.81,' +
            '"probabilities":{"BILLING":0.88,"FRAUD":0.12}}},' + USAGE + '}'
        ));

        JevChoiceResult result = JevForce.choice(
            sampleState(),
            'Which team?',
            new Map<String, String>{
                'BILLING' => 'Payments and invoices',
                'FRAUD' => 'Suspicious activity'
            }
        );

        System.assertEquals('BILLING', result.choice);
        System.assertEquals(0.81, result.confidence);
        System.assertEquals(0.88, result.probabilities.get('BILLING'));
        System.assertEquals('callout:Jev_API/v1/systemone', JevHttpMock.lastRequest.getEndpoint());
        System.assertEquals('POST', JevHttpMock.lastRequest.getMethod());
        System.assertEquals('application/json', JevHttpMock.lastRequest.getHeader('Content-Type'));

        Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(JevHttpMock.lastRequest.getBody());
        System.assertEquals('jev-latest', sent.get('model'));
        Map<String, Object> questions = (Map<String, Object>) sent.get('questions');
        Map<String, Object> question = (Map<String, Object>) questions.get('result');
        System.assertEquals('choice', question.get('type'));
        System.assertEquals('Which team?', question.get('instructions'));
        System.assertEquals(null, JevHttpMock.lastRequest.getHeader('Authorization'),
            'The Named Credential, not Apex, must supply authentication.');
    }

    @IsTest
    static void scoreSuccessReturnsDistributionAndLegend() {
        Test.setMock(HttpCalloutMock.class, new JevHttpMock(200,
            '{"model":"jev-1.13.0","answers":{"result":{' +
            '"type":"score","score":2.4,"confidence":0.77,' +
            '"legend":{"0":"Routine","1":"Attention","2":"Urgent","3":"Critical"},' +
            '"probabilities":{"0":0.0,"1":0.1,"2":0.4,"3":0.5}}},' + USAGE + '}'
        ));

        JevScoreResult result = JevForce.score(sampleState(), 'How urgent?',
            new List<String>{ 'Routine', 'Attention', 'Urgent', 'Critical' });

        System.assertEquals(2.4, result.score);
        System.assertEquals(0.77, result.confidence);
        System.assertEquals('Critical', result.legend.get('3'));
        System.assertEquals(0.5, result.probabilities.get('3'));
    }

    @IsTest
    static void noulSuccessDoesNotInventBooleanOrConfidence() {
        Test.setMock(HttpCalloutMock.class, new JevHttpMock(200,
            '{"model":"jev-1.13.0","answers":{"result":{' +
            '"type":"noul","noul":0.91}},' + USAGE + '}'
        ));

        JevNoulResult result = JevForce.noul(sampleState(), 'Escalate?');
        System.assertEquals(0.91, result.probability);
    }

    @IsTest
    static void batchExecutesAllThreeQuestionsInOneCall() {
        Test.setMock(HttpCalloutMock.class, new JevHttpMock(200,
            '{"model":"jev-1.13.0","answers":{' +
            '"route":{"type":"choice","choice":"BILLING","confidence":0.9,"probabilities":{"BILLING":0.9,"OTHER":0.1}},' +
            '"urgency":{"type":"score","score":1.5,"confidence":0.8,"legend":{"0":"Low","1":"High"},"probabilities":{"0":0.25,"1":0.75}},' +
            '"escalate":{"type":"noul","noul":0.86}},' + USAGE + '}'
        ));
        JevRequest request = new JevRequest(sampleState())
            .addChoice('route', 'Route?', new Map<String, String>{ 'BILLING' => 'Bills', 'OTHER' => 'Other' })
            .addScore('urgency', 'Urgency?', new List<String>{ 'Low', 'High' })
            .addNoul('escalate', 'Escalate?');

        JevResponse response = JevForce.execute(request);

        System.assertEquals('BILLING', response.choice('route').choice);
        System.assertEquals(1.5, response.score('urgency').score);
        System.assertEquals(0.86, response.noul('escalate').probability);
        System.assertEquals(100, response.inputTokens);
        System.assertEquals(20, response.outputTokens);
    }

    @IsTest
    static void stateSerializesSupportedValuesAndUnicode() {
        String largeText = '';
        for (Integer i = 0; i < 200; i++) largeText += 'context-' + i + ' ';
        JevState state = new JevState()
            .put('text', 'Charged twice — こんにちは 👋')
            .put('active', true)
            .put('count', 3)
            .put('longValue', Long.valueOf('2147483648'))
            .put('amount', Decimal.valueOf('1234.567'))
            .put('day', Date.newInstance(2026, 9, 21))
            .put('at', Datetime.newInstanceGmt(2026, 9, 21, 12, 34, 56))
            .put('items', new List<Object>{ 'one', 2, false })
            .put('nested', new Map<String, Object>{ 'value' => 'safe' })
            .put('large', largeText);

        String json = state.toJson();
        System.assert(json.contains('こんにちは'));
        System.assert(json.contains('1234.567'));
        System.assert(json.contains('2026-09-21'));
        System.assert(json.contains('2026-09-21T12:34:56.000Z'));
        System.assert(json.length() > 1500);
    }

    @IsTest
    static void validatesNullsQuestionDefinitionsAndConfiguration() {
        assertConfigFailureForNullState();
        assertConfigFailureForNullRequest();
        assertConfigFailureForBadChoice();
        assertConfigFailureForBadScore();
        assertConfigFailureForDuplicateId();
        assertConfigFailureForUnsupportedState();

        String oldName = JevForceConfig.namedCredential;
        JevForceConfig.namedCredential = ' ';
        try {
            JevForceConfig.validate();
            System.assert(false, 'Expected configuration exception');
        } catch (JevConfigurationException expected) {
            System.assert(expected.getMessage().contains('Named Credential'));
        } finally {
            JevForceConfig.namedCredential = oldName;
        }
    }

    @IsTest
    static void handlesDocumentedAndCommonHttpErrorsSafely() {
        assertHttpError(400, '{"message":"bad input"}', 'invalid request');
        assertHttpError(401, '{"detail":"invalid key"}', 'authentication failed');
        assertHttpError(403, '{}', 'permission denied');
        assertHttpError(404, '{}', 'endpoint not found');
        assertHttpError(429, '{"error":"slow down"}', 'rate limit exceeded');
        assertHttpError(500, '<html>failure</html>', 'service error');
        assertHttpError(529, '{}', 'service overloaded');
    }

    @IsTest
    static void rejectsEmptyMalformedAndUnexpectedResponses() {
        assertResponseFailure('', 'empty response');
        assertResponseFailure('{not json', 'malformed JSON');
        assertResponseFailure('[]', 'unexpected response structure');
        assertResponseFailure('{"model":"jev-1.13.0","answers":{},' + USAGE + '}', 'question result');
        assertResponseFailure(
            '{"model":"jev-1.13.0","answers":{"result":{"type":"noul","noul":2}},' + USAGE + '}',
            'between 0 and 1'
        );
    }

    private static JevState sampleState() {
        return new JevState().put('subject', 'Charged twice').put('previousCases', 3);
    }

    private static void assertHttpError(Integer status, String body, String expectedMessage) {
        Test.setMock(HttpCalloutMock.class, new JevHttpMock(status, body));
        try {
            JevForce.noul(sampleState(), 'Is this urgent?');
            System.assert(false, 'Expected API exception for ' + status);
        } catch (JevApiException error) {
            System.assert(error.getMessage().contains(expectedMessage), error.getMessage());
            System.assert(!error.getMessage().contains('Charged twice'), 'State must not leak into errors.');
        }
    }

    private static void assertResponseFailure(String body, String expectedMessage) {
        Test.setMock(HttpCalloutMock.class, new JevHttpMock(200, body));
        try {
            JevForce.noul(sampleState(), 'Is this urgent?');
            System.assert(false, 'Expected API exception');
        } catch (JevApiException error) {
            System.assert(error.getMessage().contains(expectedMessage), error.getMessage());
        }
    }

    private static void assertConfigFailureForNullState() {
        try {
            new JevRequest(null);
            System.assert(false, 'Expected null state failure');
        } catch (JevConfigurationException expected) {}
    }

    private static void assertConfigFailureForNullRequest() {
        try {
            JevForce.execute(null);
            System.assert(false, 'Expected null request failure');
        } catch (JevConfigurationException expected) {}
    }

    private static void assertConfigFailureForBadChoice() {
        try {
            new JevRequest(sampleState()).addChoice('route', 'Route?',
                new Map<String, String>{ 'ONLY' => 'Only one' });
            System.assert(false, 'Expected invalid Choice failure');
        } catch (JevConfigurationException expected) {}
    }

    private static void assertConfigFailureForBadScore() {
        try {
            new JevRequest(sampleState()).addScore('score', 'Score?', new List<String>{ 'Only' });
            System.assert(false, 'Expected invalid Score failure');
        } catch (JevConfigurationException expected) {}
    }

    private static void assertConfigFailureForDuplicateId() {
        try {
            new JevRequest(sampleState()).addNoul('same', 'One?').addNoul('same', 'Two?');
            System.assert(false, 'Expected duplicate id failure');
        } catch (JevConfigurationException expected) {}
    }

    private static void assertConfigFailureForUnsupportedState() {
        try {
            new JevState().put('record', new Account(Name = 'Do not serialize'));
            System.assert(false, 'Expected unsupported SObject failure');
        } catch (JevConfigurationException expected) {}
    }
}
