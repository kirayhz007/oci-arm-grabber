"""连通性自检：验证 oci_config / 私钥 / 区域 / 可用域 / 子网 是否可用。
不会创建任何实例，只做只读校验。"""
import os
import sys
import configparser

from dotenv import load_dotenv
import oci

load_dotenv("oci.env")

CONFIG_PATH = os.getenv("OCI_CONFIG", "").strip()
FREE_AD = os.getenv("OCT_FREE_AD", "").strip()
SUBNET_ID = os.getenv("OCI_SUBNET_ID", "").strip()
SHAPE = os.getenv("OCI_COMPUTE_SHAPE", "VM.Standard.A1.Flex").strip()


def fail(msg):
    print(f"❌ {msg}")
    sys.exit(1)


def ok(msg):
    print(f"✅ {msg}")


# 1. oci_config 占位符检查
raw = configparser.ConfigParser()
raw.read(CONFIG_PATH)
for key in ("user", "fingerprint", "tenancy"):
    val = raw.get("DEFAULT", key, fallback="")
    if not val or "请填入" in val:
        fail(f"oci_config 里的 {key} 还没填写")
ok("oci_config 三要素已填写")

# 2. 加载 config + 私钥
try:
    config = oci.config.from_file(CONFIG_PATH)
    oci.config.validate_config(config)
    ok(f"config 加载成功，区域 = {config['region']}")
except Exception as e:
    fail(f"加载 oci_config / 私钥失败: {e}")

# 3. 用 IdentityClient 实际调一次 API（验证密钥+认证）
try:
    iam = oci.identity.IdentityClient(config)
    tenancy = config["tenancy"]
    ads = iam.list_availability_domains(compartment_id=tenancy).data
    ad_names = [a.name for a in ads]
    ok(f"API 认证成功！该区域可用域: {ad_names}")
except Exception as e:
    fail(f"调用 Oracle API 失败（多半是 user/fingerprint/tenancy/私钥不匹配）: {e}")

# 4. 校验 OCT_FREE_AD 是否在该区域
if FREE_AD and FREE_AD not in ad_names:
    print(f"⚠️  oci.env 里的 OCT_FREE_AD='{FREE_AD}' 不在该区域可用域列表中，请核对大小写/全名")
else:
    ok(f"可用域匹配: {FREE_AD}")

# 5. 校验子网
if SUBNET_ID:
    try:
        net = oci.core.VirtualNetworkClient(config)
        subnet = net.get_subnet(SUBNET_ID).data
        ok(f"子网有效: {subnet.display_name} (VCN={subnet.vcn_id[:30]}...)")
    except Exception as e:
        fail(f"子网校验失败: {e}")
else:
    print("⚠️  未设置 OCI_SUBNET_ID（本地运行 ARM 实例必填）")

print(f"\n🎯 计划抢的实例规格: {SHAPE}")
print("✅ 自检通过，可以执行 ./run_local.sh 开始抢机。")
