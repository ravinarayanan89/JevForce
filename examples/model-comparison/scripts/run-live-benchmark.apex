// Live, read-only benchmark for Jev and Agentforce Models API.
// No Salesforce records are queried or changed. All state below is synthetic.

Map<String, Object> benchmarkMetadata = new Map<String, Object>{
    'capturedAt' => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
    'orgId' => UserInfo.getOrganizationId(),
    'measurement' => 'Single live observation per provider and scenario',
    'timing' => 'Apex wall-clock milliseconds around each provider call',
    'safety' => 'Synthetic data; no DML'
};

// ------------------------------ Case triage ------------------------------
Map<String, Object> caseStateMap = new Map<String, Object>{
    'caseNumber' => 'DEMO-CASE-001',
    'subject' => 'Fourth contact and nobody owns the missing reimbursement',
    'description' =>
        'An approved reimbursement has not appeared after five business days. ' +
        'This is my fourth contact, I keep being transferred, and I need the money ' +
        'for supplier payments tomorrow. I am extremely frustrated and need a person ' +
        'to resolve this immediately.',
    'status' => 'New',
    'origin' => 'Web',
    'currentPriority' => 'Low',
    'currentOwner' => 'Demo Owner'
};
Map<String, Object> caseQuestions = new Map<String, Object>{
    'route' => new Map<String, Object>{
        'type' => 'choice',
        'instructions' => 'Which specialist team should own this payment-services support case?',
        'criteria' => new Map<String, String>{
            'CHECKOUT_TECHNICAL' => 'Checkout failures, payment-page errors, integration faults, authorization errors, or transactions that cannot complete',
            'REIMBURSEMENTS' => 'Refunds, reimbursements, reversals, duplicate charges, disputes about money being returned, or missing credits',
            'ACCOUNT_ACCESS' => 'Login, identity verification, profile access, account recovery, or credential problems',
            'RISK_REVIEW' => 'Payments, withdrawals, balances, or accounts restricted or held for fraud, compliance, security, or risk review',
            'GENERAL_SUPPORT' => 'General questions or issues that do not clearly belong to another specialist team'
        }
    },
    'sentiment' => new Map<String, Object>{
        'type' => 'score',
        'instructions' => 'Assess the customer sentiment and emotional intensity in the case.',
        'criteria' => new List<String>{
            'Calm or neutral',
            'Concerned or disappointed',
            'Frustrated or angry',
            'Highly distressed, threatening departure, or demanding immediate intervention'
        }
    },
    'risk_hold' => new Map<String, Object>{
        'type' => 'noul',
        'instructions' => 'Does the case indicate that funds, a payment, a withdrawal, or an account is being held or restricted because of risk, fraud, compliance, or security review?'
    },
    'immediate_attention' => new Map<String, Object>{
        'type' => 'noul',
        'instructions' => 'Does this case warrant immediate human attention because of customer impact, emotional intensity, repeated failed support, or time sensitivity?'
    }
};

JevState caseState = new JevState();
for (String key : caseStateMap.keySet()) caseState.put(key, caseStateMap.get(key));
JevRequest caseJevRequest = new JevRequest(caseState)
    .addChoice('route', (String)((Map<String, Object>)caseQuestions.get('route')).get('instructions'),
        (Map<String, String>)((Map<String, Object>)caseQuestions.get('route')).get('criteria'))
    .addScore('sentiment', (String)((Map<String, Object>)caseQuestions.get('sentiment')).get('instructions'),
        (List<String>)((Map<String, Object>)caseQuestions.get('sentiment')).get('criteria'))
    .addNoul('risk_hold', (String)((Map<String, Object>)caseQuestions.get('risk_hold')).get('instructions'))
    .addNoul('immediate_attention', (String)((Map<String, Object>)caseQuestions.get('immediate_attention')).get('instructions'));

Long caseJevStarted = Datetime.now().getTime();
JevResponse caseJev = JevForce.execute(caseJevRequest);
Long caseJevElapsed = Datetime.now().getTime() - caseJevStarted;
JevChoiceResult caseRoute = caseJev.choice('route');
JevScoreResult caseSentiment = caseJev.score('sentiment');
JevNoulResult caseRisk = caseJev.noul('risk_hold');
JevNoulResult caseAttention = caseJev.noul('immediate_attention');

Map<String, Object> caseJevMetrics = new Map<String, Object>{
    'provider' => 'Jev',
    'model' => caseJev.model,
    'elapsedMilliseconds' => caseJevElapsed,
    'inputTokens' => caseJev.inputTokens,
    'outputTokens' => caseJev.outputTokens,
    'totalTokens' => caseJev.inputTokens + caseJev.outputTokens,
    'decisionCount' => 4,
    'structuredResponse' => new Map<String, Object>{
        'route' => new Map<String, Object>{
            'choice' => caseRoute.choice,
            'confidence' => caseRoute.confidence,
            'probabilities' => caseRoute.probabilities
        },
        'sentiment' => new Map<String, Object>{
            'score' => caseSentiment.score,
            'confidence' => caseSentiment.confidence,
            'legend' => caseSentiment.legend,
            'probabilities' => caseSentiment.probabilities
        },
        'riskHoldProbability' => caseRisk.probability,
        'immediateAttentionProbability' => caseAttention.probability
    }
};

String caseModelsPrompt =
    'Evaluate the following state against every question. Return only compact JSON. ' +
    'For Choice include choice and probabilities for every option. For Score include score, ' +
    'confidence, and probabilities for every level. For Noul include a yes probability. ' +
    'Do not include explanation or markdown.\n' +
    JSON.serialize(new Map<String, Object>{'state' => caseStateMap, 'questions' => caseQuestions});
JevModelsApiBenchmark.Result caseModels = JevModelsApiBenchmark.run(caseModelsPrompt);
Map<String, Object> caseModelsMetrics = new Map<String, Object>{
    'provider' => 'Agentforce Models API · Opus 4.8',
    'model' => caseModels.model,
    'elapsedMilliseconds' => caseModels.elapsedMilliseconds,
    'inputTokens' => caseModels.inputTokens,
    'outputTokens' => caseModels.outputTokens,
    'totalTokens' => caseModels.totalTokens,
    'cacheReadInputTokens' => caseModels.cacheReadInputTokens,
    'cacheWriteInputTokens' => caseModels.cacheWriteInputTokens,
    'decisionCount' => 4,
    'generatedText' => caseModels.generatedText
};

System.debug(LoggingLevel.ERROR, 'JEVFORCE_BENCHMARK_CASE|' + JSON.serialize(new Map<String, Object>{
    'metadata' => benchmarkMetadata,
    'scenario' => 'Case triage',
    'state' => caseStateMap,
    'questions' => caseQuestions,
    'jev' => caseJevMetrics,
    'agentforceModelsApi' => caseModelsMetrics
}));

// --------------------------- Lead qualification ---------------------------
Map<String, Object> leadStateMap = new Map<String, Object>{
    'name' => 'Maya Chen',
    'company' => 'Northstar Logistics Group',
    'title' => 'Chief Operating Officer',
    'industry' => 'Transportation',
    'annualRevenue' => 480000000,
    'numberOfEmployees' => 4200,
    'leadSource' => 'Web',
    'status' => 'Open - Not Contacted',
    'description' =>
        'We are selecting a platform for a multi-region rollout across 18 business units. ' +
        'Security and procurement reviews begin this month, and the executive steering ' +
        'committee wants a technical workshop this week before the budget meeting.'
};
Map<String, Object> leadQuestions = new Map<String, Object>{
    'segment' => new Map<String, Object>{
        'type' => 'choice',
        'instructions' => 'Which sales motion best matches this Lead?',
        'criteria' => new Map<String, String>{
            'ENTERPRISE' => 'Large or complex organizations with multi-team rollout, procurement, security, compliance, or substantial scale',
            'SMALL_BUSINESS' => 'Smaller organizations seeking a straightforward near-term purchase with limited implementation complexity',
            'PARTNERSHIPS' => 'Technology, referral, channel, reseller, integration, or strategic partnership opportunities',
            'NURTURE' => 'Early research, unclear fit, missing budget or timeline, education, or low evidence of an active purchase'
        }
    },
    'intent' => new Map<String, Object>{
        'type' => 'score',
        'instructions' => 'Assess the Lead buying intent from the supplied evidence.',
        'criteria' => new List<String>{
            'Exploring with no clear commercial intent',
            'Interested but missing a defined project or timeline',
            'Active evaluation with a plausible need and timeframe',
            'Ready for direct sales engagement with urgency, authority, or a concrete buying process'
        }
    },
    'immediate_follow_up' => new Map<String, Object>{
        'type' => 'noul',
        'instructions' => 'Does this Lead warrant personal follow-up within one business hour based on urgency, commercial value, authority, or a time-sensitive buying event?'
    }
};

JevState leadState = new JevState();
for (String key : leadStateMap.keySet()) leadState.put(key, leadStateMap.get(key));
JevRequest leadJevRequest = new JevRequest(leadState)
    .addChoice('segment', (String)((Map<String, Object>)leadQuestions.get('segment')).get('instructions'),
        (Map<String, String>)((Map<String, Object>)leadQuestions.get('segment')).get('criteria'))
    .addScore('intent', (String)((Map<String, Object>)leadQuestions.get('intent')).get('instructions'),
        (List<String>)((Map<String, Object>)leadQuestions.get('intent')).get('criteria'))
    .addNoul('immediate_follow_up', (String)((Map<String, Object>)leadQuestions.get('immediate_follow_up')).get('instructions'));

Long leadJevStarted = Datetime.now().getTime();
JevResponse leadJev = JevForce.execute(leadJevRequest);
Long leadJevElapsed = Datetime.now().getTime() - leadJevStarted;
JevChoiceResult leadSegment = leadJev.choice('segment');
JevScoreResult leadIntent = leadJev.score('intent');
JevNoulResult leadFollowUp = leadJev.noul('immediate_follow_up');

Map<String, Object> leadJevMetrics = new Map<String, Object>{
    'provider' => 'Jev',
    'model' => leadJev.model,
    'elapsedMilliseconds' => leadJevElapsed,
    'inputTokens' => leadJev.inputTokens,
    'outputTokens' => leadJev.outputTokens,
    'totalTokens' => leadJev.inputTokens + leadJev.outputTokens,
    'decisionCount' => 3,
    'structuredResponse' => new Map<String, Object>{
        'segment' => new Map<String, Object>{
            'choice' => leadSegment.choice,
            'confidence' => leadSegment.confidence,
            'probabilities' => leadSegment.probabilities
        },
        'intent' => new Map<String, Object>{
            'score' => leadIntent.score,
            'confidence' => leadIntent.confidence,
            'legend' => leadIntent.legend,
            'probabilities' => leadIntent.probabilities
        },
        'immediateFollowUpProbability' => leadFollowUp.probability
    }
};

String leadModelsPrompt =
    'Evaluate the following state against every question. Return only compact JSON. ' +
    'For Choice include choice and probabilities for every option. For Score include score, ' +
    'confidence, and probabilities for every level. For Noul include a yes probability. ' +
    'Do not include explanation or markdown.\n' +
    JSON.serialize(new Map<String, Object>{'state' => leadStateMap, 'questions' => leadQuestions});
JevModelsApiBenchmark.Result leadModels = JevModelsApiBenchmark.run(leadModelsPrompt);
Map<String, Object> leadModelsMetrics = new Map<String, Object>{
    'provider' => 'Agentforce Models API · Opus 4.8',
    'model' => leadModels.model,
    'elapsedMilliseconds' => leadModels.elapsedMilliseconds,
    'inputTokens' => leadModels.inputTokens,
    'outputTokens' => leadModels.outputTokens,
    'totalTokens' => leadModels.totalTokens,
    'cacheReadInputTokens' => leadModels.cacheReadInputTokens,
    'cacheWriteInputTokens' => leadModels.cacheWriteInputTokens,
    'decisionCount' => 3,
    'generatedText' => leadModels.generatedText
};

System.debug(LoggingLevel.ERROR, 'JEVFORCE_BENCHMARK_LEAD|' + JSON.serialize(new Map<String, Object>{
    'metadata' => benchmarkMetadata,
    'scenario' => 'Lead qualification',
    'state' => leadStateMap,
    'questions' => leadQuestions,
    'jev' => leadJevMetrics,
    'agentforceModelsApi' => leadModelsMetrics
}));
