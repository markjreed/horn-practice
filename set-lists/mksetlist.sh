#!/usr/bin/env bash
root=GDrive
folders=("Baritone B.C. (& Euphonium)" "Trombone")
subfolders=("" "Other Music - Archived, Summer, Etc.")
declare -A required=([rclone]=rclone [pdfunite]=poppler [qpdf]=qpdf)
declare -A rotated=([Takedown]=-)
local='numbers'
main() {
    for command in "${!required[@]}"; do
        if [[ ! -x $(command -v "$command") ]]; then
            brew install "${required[$command]}"
            if [[ $command = rclone ]]; then
                rclone config
            fi
        fi
    done
    local name=$1
    exec 3<"$name.list" || die "$name.list not found\n"
    mkdir -p "$name"
    local number=1 files folder f matches remote subfolder pat
    while IFS= read -u3 -r title; do
        mapfile -t files < <(printf '%s\n' "$local/$title"*)
        f=${files[0]}
        if [[ ! -r "$f" ]]; then
            matches=()
            for folder in "${folders[@]}"; do
                for subfolder in "${subfolders[@]}"; do
                    remote="$root:$folder${subfolder:+/$subfolder}"
                    mapfile -O "${#matches[@]}" -t matches < <(
                        rclone lsf "$remote" | sed "s|^|${remote//&/\\&}/|" | grep "$title")
                done
                if (( ${#matches[@]} )); then
                    break
                fi
            done
            if (( ${#matches[@]} == 1 )); then
                match=${matches[0]}
            elif (( ! ${#matches[@]} )); then
                die "$title not found"
            else
                warn "$title is ambiguous"
                select match in "${matches[@]}"; do
                    break
                done
            fi
            rclone copy "$match" "$local/"
            f=$local/${match##*/}
            for pat in "${!rotated[@]}"; do
                if [[ $match = *$pat* ]]; then
                    local dir=${rotated[$pat]} angle
                    if [[ $dir = 2 ]]; then
                        angle=+180
                    else
                        angle=${dir}90
                    fi
                    qpdf "$f" --rotate=${angle}:1-z --replace-input
                fi
            done
        fi
        ln "$f" "$(printf %s/%02d-%s.pdf "$name" "$number" "$title")" 
        (( number++ ))
    done
    pdfunite "$name"/*.pdf "$name.pdf" && rm -rf "$name"
}

warn() {
    printf >&2 '%s: %s\n' "$0" "$(printf "$@")"
}

die() {
    warn "$@"
    exit 1
}

main "$@"
