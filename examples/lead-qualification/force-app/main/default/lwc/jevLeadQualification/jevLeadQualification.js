import { LightningElement, api, wire } from 'lwc';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import analyzeLead from '@salesforce/apex/JevLeadQualificationController.analyzeLead';
import benchmarkWithClaude from '@salesforce/apex/JevLeadQualificationController.benchmarkWithClaude';
import getLeadHeader from '@salesforce/apex/JevLeadQualificationController.getLeadHeader';

const SEGMENT_LABELS = {
    ENTERPRISE: 'Enterprise sales',
    SMALL_BUSINESS: 'Small business sales',
    PARTNERSHIPS: 'Partnerships',
    NURTURE: 'Lead nurture'
};

const INTENT_LABELS = {
    0: 'Exploring',
    1: 'Interested',
    2: 'Active evaluation',
    3: 'Sales ready'
};

export default class JevLeadQualification extends LightningElement {
    @api recordId;
    result;
    modelsResult;
    isLoading = false;
    isModelsLoading = false;
    showMetricComparison = false;

    @wire(getLeadHeader, { leadId: '$recordId' })
    leadHeader;

    get name() {
        return this.leadHeader.data?.name || '—';
    }

    get company() {
        return this.leadHeader.data?.company || 'No company';
    }

    get title() {
        return this.leadHeader.data?.title || 'No title';
    }

    get description() {
        return this.leadHeader.data?.description || 'No qualification notes were provided for this Lead.';
    }

    get ownerName() {
        return this.result?.queueName || this.leadHeader.data?.ownerName || '—';
    }

    get buttonLabel() {
        return this.isLoading ? 'Qualifying…' : this.result ? 'Qualify again' : 'Run live qualification';
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
        return this.showMetricComparison ? 'Hide metrics' : 'Compare Metrics';
    }

    get compareButtonTitle() {
        return this.hasCompleteComparison
            ? 'Compare live latency, token usage, and judgment metrics'
            : 'Run Jev qualification and Agentforce Models API before comparing metrics';
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

    get comparisonHighlights() {
        if (!this.hasCompleteComparison) return [];
        const jevElapsed = Number(this.result.elapsedMilliseconds || 0);
        const modelsElapsed = Number(this.modelsResult.elapsedMilliseconds || 0);
        const jevTokens = Number(this.result.totalTokens || 0);
        const modelsTokens = Number(this.modelsResult.totalTokens || 0);
        const jevOutput = Number(this.result.outputTokens || 0);
        const modelsOutput = Number(this.modelsResult.outputTokens || 0);
        const speedRatio = jevElapsed > 0 ? modelsElapsed / jevElapsed : 0;
        const tokenReduction = this.reductionPercent(modelsTokens, jevTokens);
        const outputReduction = this.reductionPercent(modelsOutput, jevOutput);
        const modelChoice = this.modelsOutput?.segment?.choice;
        const agreement = modelChoice && modelChoice === this.result.segment;

        return [
            {
                key: 'latency', label: 'Observed speed',
                value: speedRatio >= 1 ? `${speedRatio.toFixed(1)}× faster` : `${(1 / speedRatio).toFixed(1)}× slower`,
                detail: `Jev ${this.formatDuration(jevElapsed)} · Agentforce ${this.formatDuration(modelsElapsed)}`,
                className: speedRatio >= 1 ? 'metric-tile metric-tile--positive' : 'metric-tile'
            },
            {
                key: 'tokens', label: 'Total-token efficiency', value: this.deltaLabel(tokenReduction),
                detail: `Jev ${jevTokens} · Agentforce ${modelsTokens}`,
                className: tokenReduction >= 0 ? 'metric-tile metric-tile--positive' : 'metric-tile'
            },
            {
                key: 'output', label: 'Output-token efficiency', value: this.deltaLabel(outputReduction),
                detail: `Jev ${jevOutput} · Agentforce ${modelsOutput}`,
                className: outputReduction >= 0 ? 'metric-tile metric-tile--positive' : 'metric-tile'
            },
            {
                key: 'agreement', label: 'Primary segment agreement',
                value: modelChoice ? (agreement ? 'Agreement' : 'Different') : 'Unavailable',
                detail: modelChoice ? `Jev ${this.result.segment} · Agentforce ${modelChoice}` : 'Generated JSON could not be parsed',
                className: agreement ? 'metric-tile metric-tile--positive' : 'metric-tile'
            }
        ];
    }

    get latencyComparisonRows() {
        return this.metricRows(Number(this.result?.elapsedMilliseconds || 0), Number(this.modelsResult?.elapsedMilliseconds || 0), (value) => this.formatDuration(value));
    }

    get tokenComparisonRows() {
        return this.metricRows(Number(this.result?.totalTokens || 0), Number(this.modelsResult?.totalTokens || 0), (value) => `${value} tokens`);
    }

    get efficiencyRows() {
        const decisions = 3;
        return [
            { key: 'jev', provider: 'Jev', elapsed: this.formatDuration(Number(this.result?.elapsedMilliseconds || 0) / decisions), tokens: this.decimal(Number(this.result?.totalTokens || 0) / decisions), output: this.decimal(Number(this.result?.outputTokens || 0) / decisions) },
            { key: 'models', provider: 'Agentforce Models API', elapsed: this.formatDuration(Number(this.modelsResult?.elapsedMilliseconds || 0) / decisions), tokens: this.decimal(Number(this.modelsResult?.totalTokens || 0) / decisions), output: this.decimal(Number(this.modelsResult?.outputTokens || 0) / decisions) }
        ];
    }

    get segmentComparisonRows() {
        const jev = this.result?.segmentProbabilities || {};
        const models = this.modelsOutput?.segment?.probabilities || {};
        return Object.keys(SEGMENT_LABELS).map((key) => {
            const jevValue = Number(jev[key] || 0);
            const modelsValue = Number(models[key] || 0);
            return {
                key, label: SEGMENT_LABELS[key],
                jevPercent: this.asPercentPrecise(jevValue), modelsPercent: this.asPercentPrecise(modelsValue),
                jevStyle: `width: ${jevValue * 100}%`, modelsStyle: `width: ${modelsValue * 100}%`
            };
        }).sort((a, b) => Number(jev[b.key] || 0) - Number(jev[a.key] || 0));
    }

    get followUpComparisonRows() {
        const jev = Number(this.result?.immediateFollowUpProbability || 0);
        const models = Number(this.modelsOutput?.immediate_follow_up?.yes || 0);
        return [{
            key: 'follow-up', label: 'Follow up within one business hour',
            jevPercent: this.asPercentPrecise(jev), modelsPercent: this.asPercentPrecise(models),
            jevStyle: `width: ${jev * 100}%`, modelsStyle: `width: ${models * 100}%`,
            gap: `${(Math.abs(jev - models) * 100).toFixed(1)} points`
        }];
    }

    get modelsOutput() {
        return this.parseGeneratedJson(this.modelsResult?.generatedText);
    }

    get segmentLabel() {
        return SEGMENT_LABELS[this.result?.segment] || this.result?.segment || '—';
    }

    get segmentConfidence() {
        return `${this.asPercent(this.result.segmentConfidence)} confidence`;
    }

    get segmentRows() {
        const probabilities = this.result?.segmentProbabilities || {};
        return Object.entries(probabilities)
            .map(([key, value]) => ({
                key,
                label: SEGMENT_LABELS[key] || key.replaceAll('_', ' ').toLowerCase(),
                percent: this.asPercent(value),
                style: `width: ${Math.max(2, Number(value) * 100)}%`,
                className: key === this.result.segment
                    ? 'probability-row probability-row--winner'
                    : 'probability-row'
            }))
            .sort((a, b) => Number(probabilities[b.key]) - Number(probabilities[a.key]));
    }

    get intentRows() {
        const probabilities = this.result?.intentProbabilities || {};
        const leader = Object.entries(probabilities)
            .sort(([, a], [, b]) => Number(b) - Number(a))[0]?.[0];
        return Object.entries(INTENT_LABELS).map(([key, label]) => {
            const value = Number(probabilities[key] || 0);
            return {
                key,
                label,
                percent: this.asPercent(value),
                style: `height: ${Math.max(4, value * 100)}%`,
                className: key === leader
                    ? 'intent-column intent-column--leader'
                    : 'intent-column'
            };
        });
    }

    get intentDisplay() {
        return Number(this.result.intentScore).toFixed(1);
    }

    get intentConfidence() {
        return `${this.asPercent(this.result.intentConfidence)} confidence`;
    }

    get followUpPair() {
        const yes = Number(this.result?.immediateFollowUpProbability || 0);
        const no = Math.max(0, 1 - yes);
        return {
            yes: this.asPercent(yes),
            no: this.asPercent(no),
            yesStyle: `width: ${yes * 100}%`,
            noStyle: `width: ${no * 100}%`
        };
    }

    get taskLabel() {
        return this.result?.followUpTaskCreated
            ? 'High-priority Task created'
            : 'No new immediate Task';
    }

    get ratingClass() {
        return this.result?.rating === 'Hot' ? 'rating rating--hot' : 'rating';
    }

    async analyze() {
        this.showMetricComparison = false;
        this.isLoading = true;
        try {
            this.result = await analyzeLead({ leadId: this.recordId });
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Lead qualification complete',
                message: `Assigned to ${this.result.queueName} with a ${this.result.rating} rating.`,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Lead qualification failed',
                message: error?.body?.message || error?.message || 'Unexpected error',
                variant: 'error',
                mode: 'sticky'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    async benchmarkModels() {
        this.showMetricComparison = false;
        this.isModelsLoading = true;
        try {
            this.modelsResult = await benchmarkWithClaude({ leadId: this.recordId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Agentforce Models API comparison complete',
                message: `${this.modelsTotalTokens} total tokens in ${this.modelsElapsedDisplay}.`,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Models API comparison failed',
                message: error?.body?.message || error?.message || 'Unexpected error',
                variant: 'error',
                mode: 'sticky'
            }));
        } finally {
            this.isModelsLoading = false;
        }
    }

    toggleMetricComparison() {
        this.showMetricComparison = !this.showMetricComparison;
    }

    asPercent(value) {
        return `${(Number(value || 0) * 100).toFixed(1)}%`;
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

    reductionPercent(baseline, candidate) {
        return baseline > 0 ? ((baseline - candidate) / baseline) * 100 : 0;
    }

    deltaLabel(value) {
        return `${Math.abs(value).toFixed(1)}% ${value >= 0 ? 'fewer' : 'more'}`;
    }

    decimal(value) {
        return Number(value || 0).toFixed(1);
    }

    asPercentPrecise(value) {
        return `${(Number(value || 0) * 100).toFixed(1)}%`;
    }

    parseGeneratedJson(value) {
        if (!value) return {};
        try {
            const clean = value.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
            return JSON.parse(clean);
        } catch (error) {
            return {};
        }
    }
}
