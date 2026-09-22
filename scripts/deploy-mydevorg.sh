#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$WORKSPACE_ROOT"

sf project deploy start \
  --source-dir jevforce/force-app \
  --source-dir jevforce/examples/model-comparison/force-app \
  --source-dir jevforce/examples/case-triage/force-app \
  --source-dir jevforce/examples/lead-qualification/force-app \
  --target-org mydevorg \
  --test-level RunSpecifiedTests \
  --tests JevForceTest \
  --tests JevCaseTriageControllerTest \
  --tests JevCaseTriageJobTest \
  --tests JevLeadQualificationControllerTest \
  --tests JevModelsApiBenchmarkTest \
  --wait 20
