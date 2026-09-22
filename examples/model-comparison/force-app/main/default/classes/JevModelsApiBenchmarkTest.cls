@IsTest
private class JevModelsApiBenchmarkTest {
    @IsTest
    static void parsesSalesforceModelsApiUsage() {
        JevModelsApiBenchmark.Result result = JevModelsApiBenchmark.fromResponse(
            '{"choice":"ENTERPRISE"}',
            new Map<String, Object>{
                'model' => 'anthropic.claude-opus-4-8',
                'usage' => new Map<String, Object>{
                    'inputTokenCount' => 120,
                    'outputTokenCount' => 30,
                    'totalTokenCount' => 150,
                    'cacheReadInputTokenCount' => 10,
                    'cacheWriteInputTokenCount' => 5
                }
            },
            1450
        );

        System.assertEquals('anthropic.claude-opus-4-8', result.model);
        System.assertEquals(120, result.inputTokens);
        System.assertEquals(30, result.outputTokens);
        System.assertEquals(150, result.totalTokens);
        System.assertEquals(1450, result.elapsedMilliseconds);
    }

    @IsTest
    static void derivesTotalWhenProviderOmitsIt() {
        JevModelsApiBenchmark.Result result = JevModelsApiBenchmark.fromResponse(
            'OK',
            new Map<String, Object>{
                'usage' => new Map<String, Object>{
                    'inputTokenCount' => 21,
                    'outputTokenCount' => 4
                }
            },
            1338
        );

        System.assertEquals(25, result.totalTokens);
        System.assertEquals(JevModelsApiBenchmark.MODEL_LABEL, result.model);
    }

}
