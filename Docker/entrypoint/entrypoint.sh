#!/bin/bash
# Routes the container's command, so the default starts the dashboard and a command such as `esphome version` still runs without starting it.
set -Eeuo pipefail

usage() {
    cat <<'EOF'
Usage: entrypoint.sh entrypoint
       entrypoint.sh COMMAND [ARG...]
       entrypoint.sh -h | --help

The image ENTRYPOINT.

  entrypoint        Create the /cache tree, then launch the device-builder dashboard.
                    This is the image's default command.
  COMMAND [ARG...]  Run COMMAND in place of the dashboard, such as `esphome version`.
                    The /cache tree is not created, so run /entrypoint/cache.sh first.
  -h, --help        Print this help and exit.
EOF
}

script_dir="$(dirname -- "${BASH_SOURCE[0]}")"

# No command starts with a dash, so only an option-shaped first word is the entrypoint's own, and a passed command keeps its own --help.
case "${1-}" in
-h | --help)
    usage
    exit 0
    ;;
entrypoint)
    if (($# > 1)); then
        echo "entrypoint.sh: unknown argument '$2' after entrypoint, see entrypoint.sh --help" >&2
        exit 2
    fi
    # Each script runs on its own rather than being sourced, so it reads its own arguments rather than these.
    "$script_dir/cache.sh"
    exec "$script_dir/dashboard.sh"
    ;;
"")
    echo "entrypoint.sh: missing command, see entrypoint.sh --help" >&2
    exit 2
    ;;
-*)
    echo "entrypoint.sh: unknown option '$1', see entrypoint.sh --help" >&2
    exit 2
    ;;
*)
    exec "$@"
    ;;
esac
