public with sharing class JevModelsApiBenchmark {
    public static final String MODEL_API_NAME =
        'sfdc_ai__DefaultBedrockAnthropicClaude48Opus';
    public static final String MODEL_LABEL = 'Agentforce Models API · Opus 4.8';

    public static Result run(String prompt) {
        if (String.isBlank(prompt)) {
            throw new BenchmarkException('The Models API comparison prompt must not be blank.');
        }

        aiplatform.ModelsAPI.createGenerations_Request request =
            new aiplatform.ModelsAPI.createGenerations_Request();
        request.modelName = MODEL_API_NAME;
        aiplatform.ModelsAPI_GenerationRequest body =
            new aiplatform.ModelsAPI_GenerationRequest();
        body.prompt = prompt;
        request.body = body;

        Long startedAt = Datetime.now().getTime();
        try {
            aiplatform.ModelsAPI.createGenerations_Response response =
                new aiplatform.ModelsAPI().createGenerations(request);
            Long elapsedMilliseconds = Datetime.now().getTime() - startedAt;
            if (response == null || response.Code200 == null ||
                response.Code200.generation == null) {
                throw new BenchmarkException('Salesforce Models API returned an empty generation.');
            }

            Map<String, Object> properties = response.Code200.parameters == null
                ? new Map<String, Object>()
                : response.Code200.parameters.properties;
            return fromResponse(
                response.Code200.generation.generatedText,
                properties,
                elapsedMilliseconds
            );
        } catch (aiplatform.ModelsAPI.createGenerations_ResponseException error) {
            throw new BenchmarkException(
                'Salesforce Models API returned HTTP ' + error.responseCode +
                ' for ' + MODEL_LABEL + '.'
            );
        }
    }

    @TestVisible
    private static Result fromResponse(
        String generatedText,
        Map<String, Object> properties,
        Long elapsedMilliseconds
    ) {
        Map<String, Object> safeProperties = properties == null
            ? new Map<String, Object>()
            : properties;
        Map<String, Object> usage = safeProperties.get('usage') instanceof Map<String, Object>
            ? (Map<String, Object>) safeProperties.get('usage')
            : new Map<String, Object>();

        Result result = new Result();
        result.model = String.isBlank((String) safeProperties.get('model'))
            ? MODEL_LABEL
            : (String) safeProperties.get('model');
        result.generatedText = generatedText;
        result.elapsedMilliseconds = elapsedMilliseconds;
        result.inputTokens = integerValue(usage.get('inputTokenCount'));
        result.outputTokens = integerValue(usage.get('outputTokenCount'));
        result.totalTokens = integerValue(usage.get('totalTokenCount'));
        result.cacheReadInputTokens = integerValue(usage.get('cacheReadInputTokenCount'));
        result.cacheWriteInputTokens = integerValue(usage.get('cacheWriteInputTokenCount'));
        if (result.totalTokens == null && result.inputTokens != null &&
            result.outputTokens != null) {
            result.totalTokens = result.inputTokens + result.outputTokens;
        }
        return result;
    }

    private static Integer integerValue(Object value) {
        return value == null ? null : Decimal.valueOf(String.valueOf(value)).intValue();
    }

    public class Result {
        @AuraEnabled public String model { get; set; }
        @AuraEnabled public String generatedText { get; set; }
        @AuraEnabled public Long elapsedMilliseconds { get; set; }
        @AuraEnabled public Integer inputTokens { get; set; }
        @AuraEnabled public Integer outputTokens { get; set; }
        @AuraEnabled public Integer totalTokens { get; set; }
        @AuraEnabled public Integer cacheReadInputTokens { get; set; }
        @AuraEnabled public Integer cacheWriteInputTokens { get; set; }
    }

    public class BenchmarkException extends Exception {}
}
