public class JevState {
    private Map<String, Object> values = new Map<String, Object>();

    public JevState put(String key, Object value) {
        if (String.isBlank(key)) {
            throw new JevConfigurationException('Jev state keys must not be blank.');
        }
        validateValue(value, 'state.' + key);
        values.put(key, value);
        return this;
    }

    public Boolean isEmpty() {
        return values.isEmpty();
    }

    public Map<String, Object> toMap() {
        return values.clone();
    }

    public String toJson() {
        return JSON.serialize(values);
    }

    private static void validateValue(Object value, String path) {
        if (value == null || value instanceof String || value instanceof Boolean ||
            value instanceof Integer || value instanceof Long || value instanceof Decimal ||
            value instanceof Date || value instanceof Datetime) {
            return;
        }

        if (value instanceof List<Object>) {
            Integer index = 0;
            for (Object item : (List<Object>) value) {
                validateValue(item, path + '[' + index + ']');
                index++;
            }
            return;
        }

        if (value instanceof Map<String, Object>) {
            for (String key : ((Map<String, Object>) value).keySet()) {
                if (String.isBlank(key)) {
                    throw new JevConfigurationException('Jev state map keys must not be blank at ' + path + '.');
                }
                validateValue(((Map<String, Object>) value).get(key), path + '.' + key);
            }
            return;
        }

        throw new JevConfigurationException(
            'Unsupported Jev state value at ' + path + '. Use String, Boolean, Integer, Long, Decimal, Date, Datetime, List, or Map.'
        );
    }
}
