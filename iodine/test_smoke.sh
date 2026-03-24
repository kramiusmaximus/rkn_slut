#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd "${repo_dir}" >/dev/null
make >/dev/null

./bin/iodine -h >/dev/null 2>&1
./bin/iodine -v >/dev/null 2>&1
./bin/iodined -h >/dev/null 2>&1
./bin/iodined -v >/dev/null 2>&1

if [[ "$(id -u)" -ne 0 ]]; then
  client_output="$(./bin/iodine -f -r -P smoke 127.0.0.1 t1.test 2>&1 || true)"
  server_output="$(./bin/iodined -f -s -4 -l 127.0.0.1 -p 55335 -P smoke 10.10.10.1 t1.test 2>&1 || true)"

  grep -q "Run as root and you'll be happy." <<<"${client_output}"
  grep -q "Run as root and you'll be happy." <<<"${server_output}"
  echo "iodine smoke test passed in non-root mode."
  echo "Full tunnel startup is not exercised here because iodine requires root privileges."
  popd >/dev/null
  exit 0
fi

echo "iodine binaries build and execute."
echo "A full end-to-end tunnel test is not automated here because it requires root-managed TUN devices and port 53."
popd >/dev/null
