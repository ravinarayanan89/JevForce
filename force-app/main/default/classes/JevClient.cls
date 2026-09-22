public class JevClient {
    public Map<String, Object> execute(JevRequest jevRequest) {
        JevForceConfig.validate();

        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + JevForceConfig.namedCredential + '/v1/systemone');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(JevForceConfig.timeoutMilliseconds);
        request.setBody(JSON.serialize(jevRequest.toPayload()));

        Long startedAt = Datetime.now().getTime();
        HttpResponse response;
        try {
            response = new Http().send(request);
        } catch (CalloutException error) {
            throw new JevApiException('Jev callout failed: ' + safeText(error.getMessage(), 300));
        }

        Integer status = response.getStatusCode();
        if (JevForceConfig.debugLogging) {
            System.debug(LoggingLevel.INFO,
                'JevForce request completed: questions=' + jevRequest.size() +
                ', status=' + status +
                ', latencyMs=' + (Datetime.now().getTime() - startedAt)
            );
        }

        if (status < 200 || status >= 300) {
            throw new JevApiException(errorMessage(status, response.getBody()));
        }
        if (String.isBlank(response.getBody())) {
            throw new JevApiException('Jev returned an empty response.');
        }

        Object decoded;
        try {
            decoded = JSON.deserializeUntyped(response.getBody());
        } catch (JSONException error) {
            throw new JevApiException('Jev returned malformed JSON.');
        }
        if (!(decoded instanceof Map<String, Object>)) {
            throw new JevApiException('Jev returned an unexpected response structure.');
        }
        return (Map<String, Object>) decoded;
    }

    private static String errorMessage(Integer status, String body) {
        String detail = extractSafeError(body);
        String message = 'Jev returned HTTP ' + status;
        if (status == 400 || status == 422) message += ': invalid request';
        else if (status == 401) message += ': authentication failed';
        else if (status == 403) message += ': permission denied';
        else if (status == 404) message += ': endpoint not found';
        else if (status == 429) message += ': rate limit exceeded';
        else if (status == 529) message += ': service overloaded';
        else if (status >= 500) message += ': service error';
        if (!String.isBlank(detail)) message += ' (' + detail + ')';
        return message;
    }

    private static String extractSafeError(String body) {
        if (String.isBlank(body)) return null;
        try {
            Object decoded = JSON.deserializeUntyped(body);
            if (!(decoded instanceof Map<String, Object>)) return null;
            Map<String, Object> values = (Map<String, Object>) decoded;
            for (String key : new List<String>{ 'message', 'detail', 'error' }) {
                Object value = values.get(key);
                if (value instanceof String) return safeText((String) value, 300);
            }
        } catch (Exception ignored) {
            return null;
        }
        return null;
    }

    private static String safeText(String value, Integer maximumLength) {
        if (String.isBlank(value)) return 'unknown callout error';
        String clean = value.replace('\n', ' ').replace('\r', ' ');
        return clean.length() <= maximumLength ? clean : clean.substring(0, maximumLength);
    }
}
