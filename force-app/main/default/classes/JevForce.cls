public class JevForce {
    private static final String SINGLE_RESULT_ID = 'result';

    public static JevChoiceResult choice(
        JevState state,
        String instructions,
        Map<String, String> choices
    ) {
        JevRequest request = new JevRequest(state)
            .addChoice(SINGLE_RESULT_ID, instructions, choices);
        return execute(request).choice(SINGLE_RESULT_ID);
    }

    public static JevScoreResult score(
        JevState state,
        String instructions,
        List<String> rubric
    ) {
        JevRequest request = new JevRequest(state)
            .addScore(SINGLE_RESULT_ID, instructions, rubric);
        return execute(request).score(SINGLE_RESULT_ID);
    }

    public static JevNoulResult noul(JevState state, String instructions) {
        JevRequest request = new JevRequest(state)
            .addNoul(SINGLE_RESULT_ID, instructions);
        return execute(request).noul(SINGLE_RESULT_ID);
    }

    public static JevResponse execute(JevRequest request) {
        if (request == null) {
            throw new JevConfigurationException('Jev request must not be null.');
        }
        Map<String, String> expectedTypes = request.getQuestionTypes();
        Map<String, Object> payload = new JevClient().execute(request);
        return parseResponse(payload, expectedTypes);
    }

    private static JevResponse parseResponse(
        Map<String, Object> payload,
        Map<String, String> expectedTypes
    ) {
        String model = requireString(payload, 'model', 'response');
        Map<String, Object> answers = requireMap(payload, 'answers', 'response');
        Map<String, Object> usage = requireMap(payload, 'usage', 'response');
        Integer inputTokens = requireInteger(usage, 'input_tokens', 'usage');
        Integer outputTokens = requireInteger(usage, 'output_tokens', 'usage');
        JevResponse response = new JevResponse(model, inputTokens, outputTokens);

        for (String id : expectedTypes.keySet()) {
            Object rawAnswer = answers.get(id);
            if (!(rawAnswer instanceof Map<String, Object>)) {
                throw structureError('missing or invalid answer for question ' + id);
            }
            Map<String, Object> answer = (Map<String, Object>) rawAnswer;
            String expectedType = expectedTypes.get(id);
            String actualType = requireString(answer, 'type', 'answer ' + id);
            if (actualType != expectedType) {
                throw structureError('answer type mismatch for question ' + id);
            }

            if (expectedType == 'choice') {
                response.choices.put(id, new JevChoiceResult(
                    requireString(answer, 'choice', 'answer ' + id),
                    requireProbability(answer, 'confidence', 'answer ' + id),
                    requireProbabilities(answer, 'probabilities', 'answer ' + id)
                ));
            } else if (expectedType == 'score') {
                response.scores.put(id, new JevScoreResult(
                    requireDecimal(answer, 'score', 'answer ' + id),
                    requireProbability(answer, 'confidence', 'answer ' + id),
                    requireLegend(answer, 'legend', 'answer ' + id),
                    requireProbabilities(answer, 'probabilities', 'answer ' + id)
                ));
            } else if (expectedType == 'noul') {
                response.nouls.put(id, new JevNoulResult(
                    requireProbability(answer, 'noul', 'answer ' + id)
                ));
            }
        }
        return response;
    }

    private static Map<String, Object> requireMap(
        Map<String, Object> parent,
        String key,
        String location
    ) {
        Object value = parent.get(key);
        if (!(value instanceof Map<String, Object>)) {
            throw structureError(location + '.' + key + ' must be an object');
        }
        return (Map<String, Object>) value;
    }

    private static String requireString(
        Map<String, Object> parent,
        String key,
        String location
    ) {
        Object value = parent.get(key);
        if (!(value instanceof String) || String.isBlank((String) value)) {
            throw structureError(location + '.' + key + ' must be a non-blank string');
        }
        return (String) value;
    }

    private static Decimal requireDecimal(
        Map<String, Object> parent,
        String key,
        String location
    ) {
        Object value = parent.get(key);
        if (value == null) throw structureError(location + '.' + key + ' must be numeric');
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception ignored) {
            throw structureError(location + '.' + key + ' must be numeric');
        }
    }

    private static Decimal requireProbability(
        Map<String, Object> parent,
        String key,
        String location
    ) {
        Decimal value = requireDecimal(parent, key, location);
        if (value < 0 || value > 1) {
            throw structureError(location + '.' + key + ' must be between 0 and 1');
        }
        return value;
    }

    private static Integer requireInteger(
        Map<String, Object> parent,
        String key,
        String location
    ) {
        Decimal value = requireDecimal(parent, key, location);
        if (value < 0 || value != value.setScale(0)) {
            throw structureError(location + '.' + key + ' must be a non-negative integer');
        }
        return value.intValue();
    }

    private static Map<String, Decimal> requireProbabilities(
        Map<String, Object> parent,
        String key,
        String location
    ) {
        Map<String, Object> raw = requireMap(parent, key, location);
        if (raw.isEmpty()) throw structureError(location + '.' + key + ' must not be empty');
        Map<String, Decimal> result = new Map<String, Decimal>();
        for (String item : raw.keySet()) {
            result.put(item, requireProbability(raw, item, location + '.' + key));
        }
        return result;
    }

    private static Map<String, String> requireLegend(
        Map<String, Object> parent,
        String key,
        String location
    ) {
        Map<String, Object> raw = requireMap(parent, key, location);
        if (raw.isEmpty()) throw structureError(location + '.' + key + ' must not be empty');
        Map<String, String> result = new Map<String, String>();
        for (String item : raw.keySet()) {
            Object value = raw.get(item);
            if (!(value instanceof String)) {
                throw structureError(location + '.' + key + '.' + item + ' must be a string');
            }
            result.put(item, (String) value);
        }
        return result;
    }

    private static JevApiException structureError(String detail) {
        return new JevApiException('Jev returned an unexpected response structure: ' + detail + '.');
    }
}
