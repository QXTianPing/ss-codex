#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

bash "$TEST_DIR/test_updates.sh"
bash "$TEST_DIR/test_fail2ban.sh"
bash "$TEST_DIR/test_package_timeouts.sh"
bash "$TEST_DIR/test_ipv4_priority.sh"
bash "$TEST_DIR/test_firewall_watchdog.sh"
bash "$TEST_DIR/test_core_regressions.sh"
bash "$TEST_DIR/test_system_regressions.sh"
bash "$TEST_DIR/test_firewall_regressions.sh"
