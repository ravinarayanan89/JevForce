public class JevForceConfig {
    public static String namedCredential = 'Jev_API';
    public static String model = 'jev-latest';
    public static Integer timeoutMilliseconds = 10000;
    public static Boolean debugLogging = false;

    private JevForceConfig() {}

    public static void validate() {
        if (String.isBlank(namedCredential)) {
            throw new JevConfigurationException('Jev Named Credential name must not be blank.');
        }
        if (String.isBlank(model)) {
            throw new JevConfigurationException('Jev model must not be blank.');
        }
        if (timeoutMilliseconds == null || timeoutMilliseconds < 1 || timeoutMilliseconds > 120000) {
            throw new JevConfigurationException('Jev timeout must be between 1 and 120000 milliseconds.');
        }
    }
}
