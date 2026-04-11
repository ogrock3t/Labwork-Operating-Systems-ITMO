#!/bin/bash

set -u
IFS=$'\n\t'

STORE_ROOT="$/home/user/.fileversion"

error() {
    echo "Error: $*" >&2
    exit 1
}

info() {
    echo "$*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || error "Required command not found: $1"
}

get_inode() {
    stat -c '%i' -- "$1" 2>/dev/null || return 1
}

get_size() {
    stat -c '%s' -- "$1" 2>/dev/null || return 1
}

get_timestamp_filename() {
    date '+%Y-%m-%d_%H-%M-%S'
}

get_timestamp_human() {
    date '+%Y-%m-%d %H:%M:%S'
}

get_hash() {
    sha256sum -- "$1" | awk '{print "sha256:" $1}'
}

get_abs_path_existing() {
    local path="$1"
    readlink -f -- "$path" 2>/dev/null || error "Cannot resolve absolute path: $path"
}

get_basename() {
    basename -- "$1"
}

get_track_dir() {
    local abs_path="$1"
    local base
    base="$(get_basename "$abs_path")"
    printf '%s/%s\n' "$STORE_ROOT" "$base"
}

get_versions_dir() {
    local abs_path="$1"
    printf '%s/versions\n' "$(get_track_dir "$abs_path")"
}

get_metadata_path() {
    local abs_path="$1"
    printf '%s/metadata.json\n' "$(get_track_dir "$abs_path")"
}

get_current_link_path() {
    local abs_path="$1"
    printf '%s/current_version\n' "$(get_track_dir "$abs_path")"
}

ensure_initialized() {
    local abs_path="$1"
    local track_dir
    track_dir="$(get_track_dir "$abs_path")"
    [[ -d "$track_dir" ]] || error "Version control is not initialized for: $abs_path"
}

resolve_tracked_abs_path() {
    local input_path="$1"

    if [[ -e "$input_path" ]]; then
        get_abs_path_existing "$input_path"
        return 0
    fi

    local guessed_base
    guessed_base="$(basename -- "$input_path")"
    local meta_path="${STORE_ROOT}/${guessed_base}/metadata.json"

    [[ -f "$meta_path" ]] || error "File does not exist and no metadata found for: $input_path"

    jq -r '.filename' "$meta_path" 2>/dev/null || error "Cannot read tracked path from metadata"
}

init_cmd() {
    local file_path="${1:-}"
    [[ -n "$file_path" ]] || error "Usage: $0 init <path_to_file>"
    [[ -e "$file_path" ]] || error "File does not exist: $file_path"
    [[ -f "$file_path" ]] || error "Not a regular file: $file_path"

    local abs_path
    abs_path="$(get_abs_path_existing "$file_path")"

    local base track_dir versions_dir metadata_path current_link
    base="$(get_basename "$abs_path")"
    track_dir="$(get_track_dir "$abs_path")"
    versions_dir="$(get_versions_dir "$abs_path")"
    metadata_path="$(get_metadata_path "$abs_path")"
    current_link="$(get_current_link_path "$abs_path")"

    [[ ! -e "$track_dir" ]] || error "Version control already initialized for: $abs_path"

    mkdir -p -- "$versions_dir" || error "Cannot create versions directory"

    local ts_human ts_file inode size hash version_name version_path
    ts_human="$(get_timestamp_human)"
    ts_file="$(get_timestamp_filename)"
    inode="$(get_inode "$abs_path")" || error "Cannot get inode"
    size="$(get_size "$abs_path")" || error "Cannot get size"
    hash="$(get_hash "$abs_path")" || error "Cannot calculate SHA-256"

    version_name="v1_${ts_file}"
    version_path="${versions_dir}/${version_name}"

    ln -- "$abs_path" "$version_path" || error "Cannot create first hard link"
    ln -s -- "versions/${version_name}" "$current_link" || error "Cannot create current_version symlink"

    jq -n \
      --arg filename "$abs_path" \
      --arg basename "$base" \
      --arg name "$version_name" \
      --arg timestamp "$ts_human" \
      --arg hash "$hash" \
      --argjson inode "$inode" \
      --argjson size "$size" \
      '{
        filename: $filename,
        basename: $basename,
        versions: [
          {
            id: 1,
            name: $name,
            timestamp: $timestamp,
            inode: $inode,
            size: $size,
            comment: "Initial version",
            hash: $hash
          }
        ],
        current_version: 1,
        created: $timestamp,
        last_updated: $timestamp
      }' > "$metadata_path" || error "Cannot write metadata.json"

    info "Version control initialized for $abs_path"
}

commit_cmd() {
    local file_path="${1:-}"
    local comment="${2:-No comment}"

    [[ -n "$file_path" ]] || error "Usage: $0 commit <path_to_file> [comment]"
    [[ -e "$file_path" ]] || error "File does not exist: $file_path"
    [[ -f "$file_path" ]] || error "Not a regular file: $file_path"

    local abs_path
    abs_path="$(get_abs_path_existing "$file_path")"
    ensure_initialized "$abs_path"

    local versions_dir metadata_path current_link
    versions_dir="$(get_versions_dir "$abs_path")"
    metadata_path="$(get_metadata_path "$abs_path")"
    current_link="$(get_current_link_path "$abs_path")"

    local current_inode current_version_path stored_inode
    current_inode="$(get_inode "$abs_path")" || error "Cannot get current file inode"

    current_version_path="$(readlink -f -- "$current_link" 2>/dev/null)" || error "Cannot resolve current_version"
    stored_inode="$(get_inode "$current_version_path")" || error "Cannot get stored inode"

    if [[ "$current_inode" == "$stored_inode" ]]; then
        info "No changes"
        return 0
    fi

    local existing_id existing_name
    existing_id="$(
        jq -r --argjson inode "$current_inode" '
          (.versions[] | select(.inode == $inode) | .id) // empty
        ' "$metadata_path"
    )" || error "Cannot search metadata"

    existing_name="$(
        jq -r --argjson inode "$current_inode" '
          (.versions[] | select(.inode == $inode) | .name) // empty
        ' "$metadata_path"
    )" || error "Cannot search metadata"

    if [[ -n "$existing_id" && -n "$existing_name" ]]; then
        rm -f -- "$current_link" || error "Cannot replace current_version symlink"
        ln -s -- "versions/${existing_name}" "$current_link" || error "Cannot update current_version symlink"

        local ts_existing
        ts_existing="$(get_timestamp_human)"

        local tmp_meta
        tmp_meta="$(mktemp)" || error "Cannot create temp file"

        jq --argjson current_version "$existing_id" \
           --arg last_updated "$ts_existing" \
           '.current_version = $current_version
            | .last_updated = $last_updated' \
           "$metadata_path" > "$tmp_meta" || {
            rm -f -- "$tmp_meta"
            error "Cannot update metadata.json"
        }

        mv -- "$tmp_meta" "$metadata_path" || error "Cannot replace metadata.json"

        info "Version with same inode already exists: $existing_name"
        return 0
    fi

    local next_id ts_human ts_file size hash version_name version_path
    next_id="$(
        jq -r '([.versions[].id] | max) + 1' "$metadata_path"
    )" || error "Cannot determine next version id"

    ts_human="$(get_timestamp_human)"
    ts_file="$(get_timestamp_filename)"
    size="$(get_size "$abs_path")" || error "Cannot get size"
    hash="$(get_hash "$abs_path")" || error "Cannot calculate SHA-256"

    version_name="v${next_id}_${ts_file}"
    version_path="${versions_dir}/${version_name}"

    ln -- "$abs_path" "$version_path" || error "Cannot create new hard link"

    rm -f -- "$current_link" || error "Cannot replace current_version symlink"
    ln -s -- "versions/${version_name}" "$current_link" || error "Cannot update current_version symlink"

    local tmp_meta
    tmp_meta="$(mktemp)" || error "Cannot create temp file"

    jq \
      --arg name "$version_name" \
      --arg timestamp "$ts_human" \
      --arg comment "$comment" \
      --arg hash "$hash" \
      --argjson id "$next_id" \
      --argjson inode "$current_inode" \
      --argjson size "$size" \
      '
      .versions += [{
        id: $id,
        name: $name,
        timestamp: $timestamp,
        inode: $inode,
        size: $size,
        comment: $comment,
        hash: $hash
      }]
      | .current_version = $id
      | .last_updated = $timestamp
      ' "$metadata_path" > "$tmp_meta" || {
        rm -f -- "$tmp_meta"
        error "Cannot update metadata.json"
    }

    mv -- "$tmp_meta" "$metadata_path" || error "Cannot replace metadata.json"

    info "Committed version $next_id: $comment"
}

restore_cmd() {
    local file_path="${1:-}"
    local version_arg="${2:-}"

    [[ -n "$file_path" && -n "$version_arg" ]] || error "Usage: $0 restore <path_to_file> <version|latest>"

    local abs_path
    abs_path="$(resolve_tracked_abs_path "$file_path")"
    ensure_initialized "$abs_path"

    local versions_dir metadata_path current_link
    versions_dir="$(get_versions_dir "$abs_path")"
    metadata_path="$(get_metadata_path "$abs_path")"
    current_link="$(get_current_link_path "$abs_path")"

    local version_id version_name

    if [[ "$version_arg" == "latest" ]]; then
        version_id="$(
            jq -r '([.versions[].id] | max)' "$metadata_path"
        )" || error "Cannot determine latest version"

        version_name="$(
            jq -r --argjson id "$version_id" '
              .versions[] | select(.id == $id) | .name
            ' "$metadata_path"
        )" || error "Cannot determine latest version name"
    else
        if [[ "$version_arg" =~ ^[0-9]+$ ]]; then
            version_id="$version_arg"
            version_name="$(
                jq -r --argjson id "$version_id" '
                  (.versions[] | select(.id == $id) | .name) // empty
                ' "$metadata_path"
            )" || error "Cannot search version by id"
        else
            version_name="$version_arg"
            version_id="$(
                jq -r --arg name "$version_name" '
                  (.versions[] | select(.name == $name) | .id) // empty
                ' "$metadata_path"
            )" || error "Cannot search version by name"
        fi
    fi

    [[ -n "${version_id:-}" && -n "${version_name:-}" ]] || error "Version not found: $version_arg"

    local version_path="${versions_dir}/${version_name}"
    [[ -e "$version_path" ]] || error "Stored version file does not exist: $version_name"

    if [[ -e "$abs_path" || -L "$abs_path" ]]; then
        rm -f -- "$abs_path" || error "Cannot remove current file"
    fi

    ln -- "$version_path" "$abs_path" || error "Cannot restore hard link to original path"

    rm -f -- "$current_link" || error "Cannot replace current_version symlink"
    ln -s -- "versions/${version_name}" "$current_link" || error "Cannot update current_version symlink"

    local ts_human tmp_meta
    ts_human="$(get_timestamp_human)"
    tmp_meta="$(mktemp)" || error "Cannot create temp file"

    jq --argjson current_version "$version_id" \
       --arg last_updated "$ts_human" \
       '.current_version = $current_version
        | .last_updated = $last_updated' \
       "$metadata_path" > "$tmp_meta" || {
        rm -f -- "$tmp_meta"
        error "Cannot update metadata.json"
    }

    mv -- "$tmp_meta" "$metadata_path" || error "Cannot replace metadata.json"

    info "Checked out version $version_arg to $abs_path"
}

main() {
    require_command stat
    require_command ln
    require_command rm
    require_command jq
    require_command sha256sum
    require_command readlink
    require_command basename
    require_command mktemp
    require_command mv
    require_command date

    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        init) init_cmd "$@" ;;
        commit) commit_cmd "$@" ;;
        restore) restore_cmd "$@" ;;
        *)
            cat >&2 <<EOF
Usage:
  $0 init <path_to_file>
  $0 commit <path_to_file> [comment]
  $0 restore <path_to_file> <version|latest>
EOF
            exit 1
            ;;
    esac
}

main "$@"
