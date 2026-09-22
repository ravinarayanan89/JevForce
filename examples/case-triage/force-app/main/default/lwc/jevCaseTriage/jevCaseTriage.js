import { LightningElement, api, wire } from 'lwc';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import analyzeCase from '@salesforce/apex/JevCaseTriageController.analyzeCase';
import benchmarkWithClaude from '@salesforce/apex/JevCaseTriageController.benchmarkWithClaude';
import getCaseHeader from '@salesforce/apex/JevCaseTriageController.getCaseHeader';

const ROUTE_LABELS = {
    CHECKOUT_TECHNICAL: 'Checkout technical',
    REIMBURSEMENTS: 'Reimbursements',
    ACCOUNT_ACCESS: 'Account access',
    RISK_REVIEW: 'Risk review',
    GENERAL_SUPPORT: 'General support'
};

const SENTIMENT_LABELS = {
    0: 'Calm or neutral',
    1: 'Concerned or disappointed',
    2: 'Frustrated or angry',
    3: 'Highly distressed'
};

export default class JevCaseTriage extends LightningElement {
    @api recordId;
    result;
    modelsResult;
    isLoading = false;
    isModelsLoading = false;
    showMetricComparison = false;
    shouldFocusMetricsModal = false;

    @wire(getCaseHeader, { caseId: '$recordId' })
    caseHeader;

    get caseNumber() {
        return this.caseHeader.data?.caseNumber || '—';
    }

    get subject() {
        return this.caseHeader.data?.subject || 'No subject';
    }

    get description() {
        return this.caseHeader.data?.description || 'No description was provided for this Case.';
    }

    get ownerName() {
        return this.result?.queueName || this.caseHeader.data?.ownerName || '—';
    }

    get buttonLabel() {
        return this.isLoading ? 'JevForce is analyzing…' : this.result ? 'Run JevForce again' : 'Run JevForce Triage';
    }

    get modelsButtonLabel() {
        return this.isModelsLoading
            ? 'Running Agentforce Models API…'
            : this.modelsResult ? 'Run Agentforce Opus again' : 'Agentforce Models API · Opus';
    }

    get isBusy() {
        return this.isLoading || this.isModelsLoading;
    }

    get compareButtonLabel() {
        return 'Compare Metrics';
    }

    get compareButtonTitle() {
        return this.hasCompleteComparison
            ? 'Compare live performance and total tokens'
            : 'Run Jev triage and Agentforce Models API before comparing metrics';
    }

    get isCompareDisabled() {
        return this.isBusy || !this.hasCompleteComparison;
    }

    get hasCompleteComparison() {
        return Boolean(this.result && this.modelsResult);
    }

    get needsComparisonData() {
        return !this.hasCompleteComparison;
    }

    get showBenchmarks() {
        return Boolean(this.result || this.modelsResult);
    }

    get jevElapsedDisplay() {
        return this.formatDuration(this.result?.elapsedMilliseconds);
    }

    get modelsElapsedDisplay() {
        return this.formatDuration(this.modelsResult?.elapsedMilliseconds);
    }

    get modelsTotalTokens() {
        return this.modelsResult?.totalTokens ?? 'Not reported';
    }

    get latencyComparisonRows() {
        return this.metricRows(
            Number(this.result?.elapsedMilliseconds || 0),
            Number(this.modelsResult?.elapsedMilliseconds || 0),
            (value) => this.formatDuration(value)
        );
    }

    get tokenComparisonRows() {
        return this.metricRows(
            Number(this.result?.totalTokens || 0),
            Number(this.modelsResult?.totalTokens || 0),
            (value) => `${value} tokens`
        );
    }

    get routeLabel() {
        return ROUTE_LABELS[this.result?.route] || this.result?.route || '—';
    }

    get routeRows() {
        const probabilities = this.result?.routeProbabilities || {};
        return Object.entries(probabilities)
            .map(([key, value]) => ({
                key,
                label: ROUTE_LABELS[key] || key.replaceAll('_', ' ').toLowerCase(),
                value,
                percent: this.asPercent(value),
                style: `width: ${Math.max(2, value * 100)}%`,
                className: key === this.result.route
                    ? 'probability-row probability-row--winner'
                    : 'probability-row'
            }))
            .sort((a, b) => b.value - a.value);
    }

    get sentimentRows() {
        const probabilities = this.result?.sentimentProbabilities || {};
        const leader = Object.entries(probabilities)
            .sort(([, a], [, b]) => b - a)[0]?.[0];
        return Object.entries(SENTIMENT_LABELS).map(([key, label]) => {
            const value = Number(probabilities[key] || 0);
            return {
                key,
                label,
                value,
                percent: this.asPercent(value),
                style: `height: ${Math.max(4, value * 100)}%`,
                className: key === leader
                    ? 'distribution-column distribution-column--leader'
                    : 'distribution-column'
            };
        });
    }

    get sentimentWidth() {
        const percentage = Math.min(100, Math.max(0, (this.result.sentimentScore / 3) * 100));
        return `width: ${percentage}%`;
    }

    get sentimentDisplay() {
        return Number(this.result.sentimentScore).toFixed(1);
    }

    get sentimentConfidenceDisplay() {
        return this.asPercent(this.result.sentimentConfidence);
    }

    get routeConfidenceDisplay() {
        return `${this.asPercent(this.result.routeConfidence)} confidence`;
    }

    get attentionDisplay() {
        return this.asPercent(this.result.immediateAttentionProbability);
    }

    get riskDisplay() {
        return this.asPercent(this.result.riskHoldProbability);
    }

    get escalationLabel() {
        return this.result.escalated ? 'Escalation enabled' : 'Standard handling';
    }

    get escalationClass() {
        return this.result.escalated ? 'status-pill status-pill--urgent' : 'status-pill';
    }

    get riskPair() {
        return this.probabilityPair(this.result?.riskHoldProbability);
    }

    get attentionPair() {
        return this.probabilityPair(this.result?.immediateAttentionProbability);
    }

    get riskVerdict() {
        return this.result.riskHoldProbability >= 0.65
            ? 'Risk hold is likely'
            : 'Risk hold is unlikely';
    }

    get attentionVerdict() {
        return this.result.immediateAttentionProbability >= 0.5
            ? 'Human attention indicated'
            : 'Standard response indicated';
    }

    async analyze() {
        this.showMetricComparison = false;
        this.isLoading = true;
        try {
            this.result = await analyzeCase({ caseId: this.recordId });
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Case triage complete',
                    message: `Assigned to ${this.result.queueName} with ${this.result.priority} priority.`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to complete triage',
                    message: this.errorMessage(error),
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    async benchmarkModels() {
        this.showMetricComparison = false;
        this.isModelsLoading = true;
        try {
            this.modelsResult = await benchmarkWithClaude({ caseId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Agentforce Models API comparison complete',
                    message: `${this.modelsTotalTokens} total tokens in ${this.modelsElapsedDisplay}.`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Models API comparison failed',
                    message: this.errorMessage(error),
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isModelsLoading = false;
        }
    }

    toggleMetricComparison() {
        this.showMetricComparison = true;
        this.shouldFocusMetricsModal = true;
    }

    closeMetricComparison() {
        this.showMetricComparison = false;
        this.shouldFocusMetricsModal = false;
    }

    handleModalKeydown(event) {
        if (event.key === 'Escape') {
            this.closeMetricComparison();
        }
    }

    renderedCallback() {
        if (this.shouldFocusMetricsModal) {
            this.template.querySelector('.metrics-modal')?.focus();
            this.shouldFocusMetricsModal = false;
        }
    }

    asPercent(value) {
        return `${Math.round(Number(value || 0) * 100)}%`;
    }

    probabilityPair(value) {
        const yes = Number(value || 0);
        const no = 1 - yes;
        return {
            yes: this.asPercent(yes),
            no: this.asPercent(no),
            yesStyle: `width: ${yes * 100}%`,
            noStyle: `width: ${no * 100}%`
        };
    }

    formatDuration(milliseconds) {
        const value = Number(milliseconds || 0);
        return value >= 1000 ? `${(value / 1000).toFixed(2)} s` : `${Math.round(value)} ms`;
    }

    metricRows(jevValue, modelsValue, formatter) {
        const maximum = Math.max(jevValue, modelsValue, 1);
        return [
            { key: 'jev', provider: 'Jev', display: formatter(jevValue), style: `width: ${(jevValue / maximum) * 100}%`, className: 'comparison-bar comparison-bar--jev' },
            { key: 'models', provider: 'Agentforce Models API', display: formatter(modelsValue), style: `width: ${(modelsValue / maximum) * 100}%`, className: 'comparison-bar comparison-bar--models' }
        ];
    }

    errorMessage(error) {
        return error?.body?.message || error?.message || 'Unexpected error while analyzing the Case.';
    }
}
