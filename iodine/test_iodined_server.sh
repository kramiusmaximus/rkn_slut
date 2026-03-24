#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
server_bin="${project_dir}/bin/iodined"
client_bin="${project_dir}/bin/iodine"

dns_ip="${DNS_IP:-127.0.0.1}"
topdomain="${DNS_DOMAIN:-t1.test}"
password="${DNS_PASSWORD:-codexsecret}"
tunnel_ip="${TUNNEL_IP:-10.10.10.1}"
server_log="$(mktemp -t iodine-server-server)"
client_log="$(mktemp -t iodine-server-client)"
server_pid=""
client_pid=""

cleanup() {
  if [[ -n "${client_pid}" ]] && kill -0 "${client_pid}" 2>/dev/null; then
    kill "${client_pid}" 2>/dev/null || true
    wait "${client_pid}" 2>/dev/null || true
  fi

  if [[ -n "${server_pid}" ]] && kill -0 "${server_pid}" 2>/dev/null; then
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
  fi

  rm -f "${server_log}" "${client_log}"
}

trap cleanup EXIT

if [[ "$(id -u)" -ne 0 ]]; then
  echo "iodined server DNS tunnel test requires root to bind UDP/53 and create the tunnel interface." >&2
  exit 2
fi

make -C "${project_dir}" >/dev/null 2>&1

"${server_bin}" -f -4 -l "${dns_ip}" -P "${password}" "${tunnel_ip}" "${topdomain}" >"${server_log}" 2>&1 &
server_pid=$!
sleep 2

if ! kill -0 "${server_pid}" 2>/dev/null; then
  cat "${server_log}" >&2
  echo "iodined exited before the server DNS tunnel test ran" >&2
  exit 1
fi

"${client_bin}" -f -r -P "${password}" "${dns_ip}" "${topdomain}" >"${client_log}" 2>&1 &
client_pid=$!

for _ in $(seq 1 20); do
  if grep -q "Connection setup complete, transmitting data." "${client_log}"; then
    echo "iodined server DNS tunnel test passed on ${dns_ip}."
    exit 0
  fi

  if [[ -n "${client_pid}" ]] && ! kill -0 "${client_pid}" 2>/dev/null; then
    break
  fi

  sleep 1
done

cat "${server_log}" >&2
cat "${client_log}" >&2
echo "iodined server failed to establish the DNS tunnel" >&2
exit 1
