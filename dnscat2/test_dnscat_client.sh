#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
client_bin="${project_dir}/client/dnscat"

dns_ip="${DNS_IP:-127.0.0.1}"
dns_port="${DNS_PORT:-53}"
dns_secret="${DNS_SECRET:-codexsecret}"
dns_domain="${DNS_DOMAIN:-}"
client_log="$(mktemp -t dnscat2-client-log)"

cleanup() {
  rm -f "${client_log}"
}

trap cleanup EXIT

make -C "${project_dir}" >/dev/null 2>&1

if [[ -z "${DNS_IP:-}" ]]; then
  echo "DNS_IP is not set; defaulting to 127.0.0.1. For a real inside/outside test, set DNS_IP to the outside server's reachable IP." >&2
fi

dns_args="server=${dns_ip},port=${dns_port}"
if [[ -n "${dns_domain}" ]]; then
  dns_args="domain=${dns_domain},${dns_args}"
fi

"${client_bin}" --dns "${dns_args}" --secret "${dns_secret}" --ping | tee "${client_log}"

grep -q "Ping response received! This seems like a valid dnscat2 server." "${client_log}" || {
  echo "dnscat client failed to establish the DNS tunnel to ${dns_ip}:${dns_port}" >&2
  exit 1
}

echo "dnscat client DNS tunnel test passed to ${dns_ip}:${dns_port}."
