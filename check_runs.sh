#!/bin/bash
# 汇总 GitHub Actions 运行情况：最近 N 轮的状态 + 当前正在跑/排队数量
#
# 用法:
#   ./check_runs.sh        查看最近 15 轮
#   ./check_runs.sh 30     查看最近 30 轮
#
# 可用环境变量 REPO 覆盖仓库，默认 kirayhz007/oci-arm-grabber

set -e
cd "$(dirname "$0")"
REPO="${REPO:-kirayhz007/oci-arm-grabber}"
N="${1:-15}"

command -v gh >/dev/null || { echo "未安装 gh CLI"; exit 1; }

echo "仓库: $REPO    最近 $N 轮"
echo "==========================================================================="
gh run list --repo "$REPO" --workflow oci-grab.yml --limit "$N" \
  --json databaseId,event,status,conclusion,createdAt \
  -q '.[] | "RUN_ID=\(.databaseId)  [\(.event)]  \(.status)/\(.conclusion // "running")  始于 \(.createdAt)"'
echo "==========================================================================="

RUNNING=$(gh run list --repo "$REPO" --status in_progress --json databaseId -q 'length' 2>/dev/null || echo "?")
QUEUED=$(gh run list --repo "$REPO" --status queued --json databaseId -q 'length' 2>/dev/null || echo "?")
echo "当前: 正在跑 ${RUNNING} 轮 / 排队 ${QUEUED} 轮   (并发上限=1跑+1排队，不会堆积)"
echo
echo "看某一轮日志摘要:  ./check_logs.sh <RUN_ID>"
echo "网页:             https://github.com/$REPO/actions"
