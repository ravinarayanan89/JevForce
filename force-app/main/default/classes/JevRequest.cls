public class JevRequest {
    private JevState state;
    private Map<String, Object> questions = new Map<String, Object>();
    private Map<String, String> questionTypes = new Map<String, String>();

    public JevRequest(JevState state) {
        if (state == null) {
            throw new JevConfigurationException('Jev state must not be null.');
        }
        this.state = state;
    }

    public JevRequest addChoice(String id, String instructions, Map<String, String> choices) {
        validateQuestion(id, instructions);
        if (choices == null || choices.size() < 2 || choices.size() > 255) {
            throw new JevConfigurationException('A Jev Choice requires between 2 and 255 options.');
        }
        Map<String, Object> criteria = new Map<String, Object>();
        for (String option : choices.keySet()) {
            if (String.isBlank(option)) {
                throw new JevConfigurationException('Jev Choice option names must not be blank.');
            }
            criteria.put(option, choices.get(option));
        }
        questions.put(id, new Map<String, Object>{
            'type' => 'choice',
            'instructions' => instructions,
            'criteria' => criteria
        });
        questionTypes.put(id, 'choice');
        return this;
    }

    public JevRequest addScore(String id, String instructions, List<String> rubric) {
        validateQuestion(id, instructions);
        if (rubric == null || rubric.size() < 2 || rubric.size() > 10) {
            throw new JevConfigurationException('A Jev Score requires between 2 and 10 ordered levels.');
        }
        List<Object> criteria = new List<Object>();
        for (String level : rubric) {
            if (String.isBlank(level)) {
                throw new JevConfigurationException('Jev Score levels must not be blank.');
            }
            criteria.add(level);
        }
        questions.put(id, new Map<String, Object>{
            'type' => 'score',
            'instructions' => instructions,
            'criteria' => criteria
        });
        questionTypes.put(id, 'score');
        return this;
    }

    public JevRequest addNoul(String id, String instructions) {
        validateQuestion(id, instructions);
        questions.put(id, new Map<String, Object>{
            'type' => 'noul',
            'instructions' => instructions
        });
        questionTypes.put(id, 'noul');
        return this;
    }

    public Integer size() {
        return questions.size();
    }

    public Map<String, Object> toPayload() {
        if (questions.isEmpty()) {
            throw new JevConfigurationException('A Jev request must contain at least one question.');
        }
        return new Map<String, Object>{
            'model' => JevForceConfig.model,
            'state' => state.toMap(),
            'questions' => questions
        };
    }

    public Map<String, String> getQuestionTypes() {
        return questionTypes.clone();
    }

    private void validateQuestion(String id, String instructions) {
        if (String.isBlank(id)) {
            throw new JevConfigurationException('Jev question id must not be blank.');
        }
        if (questions.containsKey(id)) {
            throw new JevConfigurationException('Duplicate Jev question id: ' + id);
        }
        if (String.isBlank(instructions)) {
            throw new JevConfigurationException('Jev question instructions must not be blank.');
        }
    }
}
