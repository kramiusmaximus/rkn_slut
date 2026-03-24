#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
client_bin="${project_dir}/bin/iodine"

dns_ip="${DNS_IP:-127.0.0.1}"
topdomain="${DNS_DOMAIN:-t1.test}"
password="${DNS_PASSWORD:-codexsecret}"
client_log="$(mktemp -t iodine-client-log)"

cleanup() {
  rm -f "${client_log}"
}

trap cleanup EXIT

if [[ "$(id -u)" -ne 0 ]]; then
  echo "iodine client requires root to create the tunnel interface." >&2
  exit 2
fi

make -C "${project_dir}" >/dev/null 2>&1

if [[ -z "${DNS_IP:-}" ]]; then
  echo "DNS_IP is not set; defaulting to 127.0.0.1. For a real inside/outside test, set DNS_IP to the outside iodined server IP." >&2
fi

"${client_bin}" -f -r -P "${password}" "${dns_ip}" "${topdomain}" 2>&1 | tee "${client_log}"

grep -q "Connection setup complete, transmitting data." "${client_log}" || {
  echo "iodine client failed to establish the DNS tunnel to ${dns_ip}:53" >&2
  exit 1
}

echo "iodine client DNS tunnel test passed to ${dns_ip}:53."
