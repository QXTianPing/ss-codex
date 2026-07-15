#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test_helper.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"

# shellcheck source=../vpsbox.sh
source "$REPO_DIR/vpsbox.sh"

test_cleanup() {
    if [ "${KEEP_TEST_TMP:-0}" = "1" ]; then
        printf '保留测试临时目录：%s\n' "$TEST_TMP" >&2
    else
        rm -rf -- "$TEST_TMP"
    fi
}
trap test_cleanup EXIT

chown() { :; }

reset_case() {
    local name="$1"

    CASE_DIR="$TEST_TMP/$name"
    VPSBOX_STATE_DIR="$CASE_DIR/state"
    CHANGE_MANIFEST="$VPSBOX_STATE_DIR/changes.env"
    CHANGE_BACKUP_DIR="$VPSBOX_STATE_DIR/backups"
    GAI_CONF="$CASE_DIR/gai.conf"
    mkdir -p "$CASE_DIR"
}

test_repeated_enable_is_idempotent() {
    local original="$TEST_TMP/original-gai.conf" count

    reset_case repeated
    printf '# original\nlabel ::1/128 0\n' > "$GAI_CONF"
    cp "$GAI_CONF" "$original"

    enable_ipv4_priority >/dev/null
    enable_ipv4_priority >/dev/null

    count="$(grep -Ec '^precedence ::ffff:0:0/96 100$' "$GAI_CONF")"
    assert_eq 1 "$count" "重复执行后应只有一条 IPv4 优先规则"
    if find "$CASE_DIR" -maxdepth 1 -name 'gai.conf.bak.*' -print -quit | grep -q .; then
        fail "不应再生成时间戳备份"
    fi
    cmp -s "$original" "$CHANGE_BACKUP_DIR/GAI_CONF" || fail "唯一备份应保存首次修改前原文"
    assert_file_contains "$CHANGE_MANIFEST" '^BACKUP_GAI_CONF=file$'
    assert_file_contains "$CHANGE_MANIFEST" '^APPLIED_GAI_CONF=1$'

    restore_change_file GAI_CONF "$GAI_CONF"
    cmp -s "$original" "$GAI_CONF" || fail "恢复后应逐字还原原配置"
}

test_preconfigured_state_is_noop() {
    reset_case preconfigured
    printf '# managed elsewhere\nprecedence ::ffff:0:0/96 100\n' > "$GAI_CONF"

    enable_ipv4_priority >/dev/null

    [ ! -e "$CHANGE_MANIFEST" ] || fail "原本已启用时不应创建变更清单"
    [ ! -e "$CHANGE_BACKUP_DIR/GAI_CONF" ] || fail "原本已启用时不应创建备份"
    assert_eq 1 "$(grep -Ec '^precedence ::ffff:0:0/96 100$' "$GAI_CONF")"
}

test_absent_file_restores_to_absent() {
    reset_case absent
    [ ! -e "$GAI_CONF" ] || fail "测试前 gai.conf 应不存在"

    enable_ipv4_priority >/dev/null
    [ -f "$GAI_CONF" ] || fail "启用后应创建 gai.conf"
    assert_file_contains "$CHANGE_MANIFEST" '^BACKUP_GAI_CONF=absent$'

    restore_change_file GAI_CONF "$GAI_CONF"
    [ ! -e "$GAI_CONF" ] || fail "恢复后应删除原本不存在的 gai.conf"
}

main() {
    local name test status passed=0
    local -a required=(enable_ipv4_priority ipv4_priority_state restore_change_file)
    local -a tests=(
        test_repeated_enable_is_idempotent
        test_preconfigured_state_is_noop
        test_absent_file_restores_to_absent
    )

    for name in "${required[@]}"; do
        require_function "$name"
    done
    for test in "${tests[@]}"; do
        set +e
        (set -e; "$test")
        status=$?
        set -e
        if [ "$status" -eq 0 ]; then
            printf 'ok - %s\n' "$test"
            passed=$((passed + 1))
        else
            printf 'not ok - %s\n' "$test" >&2
            return 1
        fi
    done
    printf '%s IPv4 priority tests passed.\n' "$passed"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
