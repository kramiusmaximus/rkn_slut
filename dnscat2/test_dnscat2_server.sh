#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
server_dir="${project_dir}/server"

dns_ip="${DNS_IP:-0.0.0.0}"
dns_port="${DNS_PORT:-53}"
dns_secret="${DNS_SECRET:-codexsecret}"
bundle_log="$(mktemp -t dnscat2-server-bundle)"
server_log="$(mktemp -t dnscat2-server-log)"
stdin_fifo="$(mktemp -u -t dnscat2-server-stdin)"
server_pid=""

cleanup() {
  if [[ -n "${server_pid}" ]] && kill -0 "${server_pid}" 2>/dev/null; then
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
  fi

  exec 3>&- 2>/dev/null || true
  rm -f "${bundle_log}" "${server_log}" "${stdin_fifo}"
}

trap cleanup EXIT

pushd "${server_dir}" >/dev/null
if ! bundle install --path vendor/bundle >"${bundle_log}" 2>&1; then
  cat "${bundle_log}" >&2
  echo "dnscat2 server dependencies failed to install." >&2
  exit 2
fi

mkfifo "${stdin_fifo}"
exec 3<>"${stdin_fifo}"

bundle exec ruby dnscat2.rb --dns "host=${dns_ip},port=${dns_port}" --secret "${dns_secret}" --firehose <"${stdin_fifo}" >"${server_log}" 2>&1 &
server_pid=$!
popd >/dev/null

sleep 2

if ! kill -0 "${server_pid}" 2>/dev/null; then
  cat "${server_log}" >&2
  echo "dnscat2 server failed to start on ${dns_ip}:${dns_port}" >&2
  exit 1
fi

echo "dnscat2 server is listening on ${dns_ip}:${dns_port}."
echo "Run the inside-host client with:"
echo "  DNS_IP=<outside-server-ip> DNS_PORT=${dns_port} DNS_SECRET=${dns_secret} ./test_dnscat_client.sh"

wait "${server_pid}"
