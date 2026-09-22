public class JevScoreResult {
    public Decimal score { get; private set; }
    public Decimal confidence { get; private set; }
    public Map<String, String> legend { get; private set; }
    public Map<String, Decimal> probabilities { get; private set; }

    public JevScoreResult(
        Decimal score,
        Decimal confidence,
        Map<String, String> legend,
        Map<String, Decimal> probabilities
    ) {
        this.score = score;
        this.confidence = confidence;
        this.legend = legend;
        this.probabilities = probabilities;
    }
}
