#!/usr/bin/env bash
set -euo pipefail
sf apex run test --target-org mydevorg --test-level RunLocalTests --wait 20 --result-format human
