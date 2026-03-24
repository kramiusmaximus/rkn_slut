#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
client_bin="${project_dir}/client/dnscat"
server_dir="${project_dir}/server"

dns_ip="${DNS_IP:-127.0.0.1}"
dns_port="${DNS_PORT:-$((RANDOM % 1000 + 55000))}"
dns_secret="${DNS_SECRET:-codexsecret}"
server_log="$(mktemp -t dnscat2-server-server)"
client_log="$(mktemp -t dnscat2-server-client)"
bundle_log="$(mktemp -t dnscat2-server-bundle)"
stdin_fifo="$(mktemp -u -t dnscat2-server-stdin)"
server_pid=""

cleanup() {
  if [[ -n "${server_pid}" ]] && kill -0 "${server_pid}" 2>/dev/null; then
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
  fi

  exec 3>&- 2>/dev/null || true
  rm -f "${stdin_fifo}" "${server_log}" "${client_log}" "${bundle_log}"
}

trap cleanup EXIT

make -C "${project_dir}" >/dev/null 2>&1

mkfifo "${stdin_fifo}"
exec 3<>"${stdin_fifo}"

pushd "${server_dir}" >/dev/null
if ! bundle install --path vendor/bundle >"${bundle_log}" 2>&1; then
  cat "${bundle_log}" >&2
  echo "dnscat2 server dependencies failed to install. In this clone, the sha3 gem build currently fails on macOS with an unsupported -march=nocona flag." >&2
  exit 2
fi

bundle exec ruby dnscat2.rb --dns "host=${dns_ip},port=${dns_port}" --secret "${dns_secret}" --firehose <"${stdin_fifo}" >"${server_log}" 2>&1 &
server_pid=$!
popd >/dev/null

sleep 1

if ! kill -0 "${server_pid}" 2>/dev/null; then
  cat "${server_log}" >&2
  echo "dnscat2 server exited before the server DNS tunnel test ran" >&2
  exit 1
fi

"${client_bin}" --dns "server=${dns_ip},port=${dns_port}" --secret "${dns_secret}" --ping | tee "${client_log}"

grep -q "Ping response received! This seems like a valid dnscat2 server." "${client_log}" || {
  cat "${server_log}" >&2
  echo "dnscat2 server failed the DNS tunnel handshake" >&2
  exit 1
}

echo "dnscat2 server DNS tunnel test passed on ${dns_ip}:${dns_port}."
