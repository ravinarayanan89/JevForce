public class JevChoiceResult {
    public String choice { get; private set; }
    public Decimal confidence { get; private set; }
    public Map<String, Decimal> probabilities { get; private set; }

    public JevChoiceResult(String choice, Decimal confidence, Map<String, Decimal> probabilities) {
        this.choice = choice;
        this.confidence = confidence;
        this.probabilities = probabilities;
    }
}
