#!/bin/bash
# Local (macOS) runner — activates the venv and runs main.py
# 用法:
#   ./run_local.sh          前台运行（按 Ctrl+C 停止）
#   ./run_local.sh bg       后台运行，日志写入 nohup.out

set -e
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  echo "未找到 .venv 虚拟环境，先创建并安装依赖..."
  python3 -m venv .venv
  .venv/bin/pip install --upgrade pip
  .venv/bin/pip install -r requirements.txt
fi

# 基础校验
for f in oci_config oci.env; do
  [ -f "$f" ] || { echo "缺少 $f"; exit 1; }
done

if grep -q "请填入" oci_config; then
  echo "⚠️  oci_config 里还有未填写的占位符（请填入...），请先补全你的 Oracle 凭证。"
  exit 1
fi

if [ "$1" = "bg" ]; then
  echo "后台启动中，日志见 nohup.out ..."
  nohup .venv/bin/python main.py >> nohup.out 2>&1 &
  echo "PID: $!"
else
  exec .venv/bin/python main.py
fi
