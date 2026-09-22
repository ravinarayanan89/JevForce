public class JevResponse {
    public String model { get; private set; }
    public Integer inputTokens { get; private set; }
    public Integer outputTokens { get; private set; }
    public Map<String, JevChoiceResult> choices { get; private set; }
    public Map<String, JevScoreResult> scores { get; private set; }
    public Map<String, JevNoulResult> nouls { get; private set; }

    public JevResponse(String model, Integer inputTokens, Integer outputTokens) {
        this.model = model;
        this.inputTokens = inputTokens;
        this.outputTokens = outputTokens;
        choices = new Map<String, JevChoiceResult>();
        scores = new Map<String, JevScoreResult>();
        nouls = new Map<String, JevNoulResult>();
    }

    public JevChoiceResult choice(String id) {
        return choices.get(id);
    }

    public JevScoreResult score(String id) {
        return scores.get(id);
    }

    public JevNoulResult noul(String id) {
        return nouls.get(id);
    }
}
