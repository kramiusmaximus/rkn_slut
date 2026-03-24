#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
server_bin="${project_dir}/bin/iodined"
tmp_dir="${TMPDIR:-/tmp}"

dns_ip="${DNS_IP:-0.0.0.0}"
dns_port="${DNS_PORT:-53}"
topdomain="${DNS_DOMAIN:-t1.test}"
password="${DNS_PASSWORD:-codexsecret}"
tunnel_ip="${TUNNEL_IP:-10.10.10.1}"
server_log="$(mktemp "${tmp_dir}/iodine-server-log.XXXXXX")"
server_pid=""

cleanup() {
  if [[ -n "${server_pid}" ]] && kill -0 "${server_pid}" 2>/dev/null; then
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
  fi

  rm -f "${server_log}"
}

trap cleanup EXIT

if [[ "$(id -u)" -ne 0 ]]; then
  echo "iodined requires root to bind UDP/${dns_port} and create the tunnel interface." >&2
  exit 2
fi

make -C "${project_dir}" >/dev/null 2>&1

"${server_bin}" -f -4 -l "${dns_ip}" -p "${dns_port}" -P "${password}" "${tunnel_ip}" "${topdomain}" >"${server_log}" 2>&1 &
server_pid=$!

sleep 2

if ! kill -0 "${server_pid}" 2>/dev/null; then
  cat "${server_log}" >&2
  echo "iodined failed to start on ${dns_ip}:${dns_port}" >&2
  exit 1
fi

echo "iodined server is listening on ${dns_ip}:${dns_port} for ${topdomain}."
echo "Run the inside-host client with:"
echo "  sudo DNS_IP=<outside-server-ip> DNS_DOMAIN=${topdomain} DNS_PASSWORD=${password} ./test_iodine_client.sh"
echo "Note: iodine clients only talk to UDP/53, so DNS_PORT should usually remain 53."

wait "${server_pid}"
