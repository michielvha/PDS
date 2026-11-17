#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/maintenance/docker_cleanup.sh) `
#
# Safe docker/container reclaim for dev machines. Dev tooling (images, build
# cache, kind/containerd layers, anonymous volumes) silently grows to hundreds
# of GiB. These helpers reclaim it WITHOUT deleting data you care about: named
# volumes you explicitly protect are never pruned, and volumes attached to a
# running container are protected by docker itself.

# Function: docker_safe_prune
# Description: Reclaim build cache, dangling images, stopped containers and
#   unused volumes — while protecting a list of named volumes (e.g. databases).
#   In-use volumes are already safe (docker will not prune them); the keep-list
#   adds belt-and-braces protection for volumes that may be temporarily detached.
# Usage: docker_safe_prune [-k "vol1 vol2 ..."] [--no-volumes]
#   e.g. docker_safe_prune -k "deploy_postgres_data stackweaver_system-keys"
docker_safe_prune() {
    local keep="" do_volumes=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -k|--keep) keep="$2"; shift 2 ;;
            --no-volumes) do_volumes=0; shift ;;
            *) echo "unknown arg: $1" >&2; return 1 ;;
        esac
    done

    command -v docker >/dev/null || { echo "docker not found" >&2; return 1; }

    echo "== docker_safe_prune =="
    echo "-- build cache --";        docker builder prune -af   | tail -1
    echo "-- dangling images --";    docker image prune -f      | tail -1
    echo "-- stopped containers --"; docker container prune -f  | tail -1

    if [[ $do_volumes -eq 1 ]]; then
        echo "-- unused volumes (protecting: ${keep:-<none>}) --"
        # Re-attach protection: temporarily label kept volumes so a global prune
        # cannot take them even if currently detached. We prune by explicit list
        # of "dangling" (unused) volumes MINUS the keep-list, which is safest.
        local protected=" $keep "
        local v freed=0
        while read -r v; do
            [[ -z "$v" ]] && continue
            if [[ "$protected" == *" $v "* ]]; then
                echo "   keep (protected): $v"
                continue
            fi
            docker volume rm "$v" >/dev/null 2>&1 && freed=$((freed+1))
        done < <(docker volume ls -qf dangling=true)
        echo "   removed $freed unused volume(s)"
    fi

    echo "-- result --"
    docker system df
}

# Function: docker_disk_report
# Description: Show where docker is spending disk and what is reclaimable,
#   plus which named volumes are in use (so you know what a prune will keep).
# Usage: docker_disk_report
docker_disk_report() {
    command -v docker >/dev/null || { echo "docker not found" >&2; return 1; }
    echo "== docker disk usage =="
    docker system df
    echo "== named volumes in use (protected by a prune) =="
    local v
    for v in $(docker volume ls -q); do
        local users
        users=$(docker ps -a --filter volume="$v" --format '{{.Names}}' | paste -sd, -)
        [[ -n "$users" ]] && printf '  %-45s <- %s\n' "$v" "$users"
    done
}
