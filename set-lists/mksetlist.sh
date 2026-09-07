#!/usr/bin/env bash
root=GDrive
folders=("Baritone B.C. (& Euphonium)" "Trombone")
subfolders=("" "Other Music - Archived, Summer, Etc.")
local='numbers'
main() {
    local name=$1
    exec 3<"$name.list" || die "$name.list not found\n"
    mkdir -p "$name"
    local number=1 files folder f matches remote subfolder
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
            f=$local/$match
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
