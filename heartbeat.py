"""每日心跳：查 Oracle 是否已有 ARM 实例，并往 Discord 发一条状态消息。
- 已抢到 → 🎉 报告实例详情
- 未抢到 → ✅ 报告仍在值守
只读，不创建任何资源。"""
import os
import sys

from dotenv import load_dotenv
import requests
import oci

load_dotenv("oci.env")

WEBHOOK = os.getenv("DISCORD_WEBHOOK", "").strip()
CONFIG_PATH = os.getenv("OCI_CONFIG", "").strip()
ARM_SHAPE = "VM.Standard.A1.Flex"
RUN_DATE = os.getenv("RUN_DATE", "").strip()  # 由工作流注入的日期，避免脚本里取时间


def notify(msg: str):
    print(msg)
    if WEBHOOK:
        try:
            requests.post(WEBHOOK, json={"content": msg}, timeout=20).raise_for_status()
        except requests.RequestException as e:
            print(f"Discord 发送失败: {e}")


try:
    config = oci.config.from_file(CONFIG_PATH)
    tenancy = config["tenancy"]
    compute = oci.core.ComputeClient(config)
    instances = compute.list_instances(compartment_id=tenancy).data
    arm = [i for i in instances
           if i.shape == ARM_SHAPE and i.lifecycle_state in ("RUNNING", "PROVISIONING")]
    stamp = f"（截至 {RUN_DATE}）" if RUN_DATE else ""
    if arm:
        inst = arm[0]
        notify(
            f"🎉🎉🎉 抢到 ARM 实例啦！{stamp}\n"
            f"名称: {inst.display_name}\n状态: {inst.lifecycle_state}\n"
            f"OCID: {inst.id}\n用本机的 id_rsa_private 私钥 ssh ubuntu@<公网IP> 登录。"
        )
    else:
        notify(f"✅ 抢机器人仍在值守，Oracle 暂无 ARM 容量，尚未抢到，继续蹲。{stamp}")
except Exception as e:
    notify(f"⚠️ 心跳检查出错（不影响抢机本身）: {e}")
    sys.exit(0)
