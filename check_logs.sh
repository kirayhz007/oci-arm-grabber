#!/bin/bash
# 汇总某一轮的执行日志：统计每种结果出现次数（无容量 / 限流 / 其它），并判断是否抢到实例。
#
# 用法:
#   ./check_logs.sh             汇总“最新一轮已完成”的运行
#   ./check_logs.sh <RUN_ID>    汇总指定那一轮（RUN_ID 用 ./check_runs.sh 查）
#
# 注意: 进行中的运行日志 GitHub 读不到，需等该轮结束。

set -e
cd "$(dirname "$0")"
REPO="${REPO:-kirayhz007/oci-arm-grabber}"
RID="$1"

command -v gh >/dev/null || { echo "未安装 gh CLI"; exit 1; }

if [ -z "$RID" ]; then
  RID=$(gh run list --repo "$REPO" --status completed --limit 1 --json databaseId -q '.[0].databaseId')
  echo "未指定 RUN_ID，使用最新已完成的一轮: $RID"
fi

STATUS=$(gh run view "$RID" --repo "$REPO" --json status -q .status 2>/dev/null || echo "unknown")
if [ "$STATUS" != "completed" ]; then
  echo "⚠️  该轮状态为 '$STATUS'，进行中的运行日志无法读取（GitHub 限制）。"
  echo "    想看实时进度请用网页: https://github.com/$REPO/actions/runs/$RID"
  exit 0
fi

echo "正在拉取 RUN $RID 的日志..."
LOG=$(gh run view "$RID" --repo "$REPO" --log 2>/dev/null)

echo
echo "===== RUN $RID 执行摘要 ====="
echo "--- 各次尝试结果统计 ---"
echo "$LOG" | grep -E "Output: \{'status'" \
  | sed -E "s/.*'status': ([0-9]+), 'code': '([^']+)'.*/  \2 (\1)/" \
  | sort | uniq -c \
  | sed -E "s/500\)/500 = 无容量 Out-of-capacity)/; s/429\)/429 = 限流 TooManyRequests)/" \
  || echo "  (本轮无尝试记录)"

echo "--- 是否抢到实例 ---"
if echo "$LOG" | grep -q '##\[notice\].*抢到'; then
  echo "  🎉🎉🎉 抢到了！实例已创建！"
  echo "  详情(实例 OCID / 公网 IP)见该轮日志的 Report 步骤:"
  echo "  https://github.com/$REPO/actions/runs/$RID"
else
  echo "  尚未抢到（仍在等 Oracle 释放容量），继续跑。"
fi
