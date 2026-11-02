#!/usr/bin/env bash
# Reuse the cloud checkout and pinned Flutter/Android toolchain; no worktree needed.
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
container_name=smartpos-toolchain
image=ghcr.io/cirruslabs/flutter@sha256:1a9c4cebfa976b4dc4c6557727ad3083ba0fde0d3d24a969fb77ac60d30c69ac
docker_local() {
  env -u DOCKER_HOST -u DOCKER_CONTEXT -u DOCKER_TLS -u DOCKER_TLS_VERIFY -u DOCKER_CERT_PATH \
    docker --host=unix:///var/run/docker.sock "$@"
}
docker_local info >/dev/null
if docker_local container inspect "$container_name" >/dev/null 2>&1; then
  mounted_dir="$(docker_local inspect --format '{{range .Mounts}}{{if eq .Destination "/project"}}{{.Source}}{{end}}{{end}}' "$container_name")"
  test "$mounted_dir" = "$project_dir" || { echo 'Toolchain container belongs to another checkout.' >&2; exit 1; }
  docker_local start "$container_name" >/dev/null
else
  docker_local pull "$image"
  extra_args=()
  proxy_address="$(getent ahostsv4 proxy | awk 'NR == 1 {print $1}')"
  if [[ -n "$proxy_address" ]]; then extra_args+=(--add-host "proxy:$proxy_address"); fi
  docker_local run -d --name "$container_name" \
    "${extra_args[@]}" \
    --mount "type=bind,src=$project_dir,dst=/project" \
    -e HTTP_PROXY -e HTTPS_PROXY -e NO_PROXY \
    -w /project "$image" sleep infinity >/dev/null
fi
if [[ -n "${CODEX_PROXY_CERT:-}" && -f "$CODEX_PROXY_CERT" ]]; then
  docker_local cp "$CODEX_PROXY_CERT" "$container_name:/usr/local/share/ca-certificates/cloud-proxy.crt"
  docker_local exec "$container_name" update-ca-certificates >/dev/null
fi
# JVM tools need explicit proxy properties. Preserve TLS and the inherited proxy.
docker_local exec -i "$container_name" python3 - <<'PY'
import os
from pathlib import Path
from urllib.parse import urlsplit
proxy = urlsplit(os.environ.get('HTTPS_PROXY') or os.environ.get('https_proxy') or '')
if proxy.hostname:
    path = Path('/root/.gradle/gradle.properties')
    path.parent.mkdir(parents=True, exist_ok=True)
    keys = {f'systemProp.{scheme}.proxy{field}' for scheme in ['http', 'https'] for field in ['Host', 'Port']}
    previous = path.read_text().splitlines() if path.exists() else []
    retained = [line for line in previous if line.split('=', 1)[0].strip() not in keys]
    path.write_text(('\n'.join(retained) + '\n' if retained else '') + ''.join(
        f'systemProp.{scheme}.proxyHost={proxy.hostname}\n'
        f'systemProp.{scheme}.proxyPort={proxy.port or 8080}\n'
        for scheme in ['http', 'https']))
PY
if [[ $# -eq 0 ]]; then set -- flutter --version; fi
docker_local exec "$container_name" "$@"
