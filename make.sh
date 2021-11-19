#!/bin/sh

NAME="$( basename "${0}"; printf a )"; NAME="${NAME%?a}"

show_help() {
  printf %s\\n "SYNOPSIS" >&2
  printf %s\\n "  ${NAME} <JOB> [<arg> ...]" >&2


  printf %s\\n "" "JOBS" >&2
  <"${0}" awk '
    /^my_make/ { run = 1; }
    /^\}/ { run = 0; }
    run && /^    in|^    ;;/ {
      sub(/^ *in /, "  ", $0);
      sub(/^ *;; /, "  ", $0);
      sub(/\) *#/, "\t", $0);
      sub(/\).*/, "", $0);
      print $0;
    }
  ' >&2

  exit 1
}

my_dir="$( dirname "${0}"; printf a )"; my_dir="${my_dir%?a}"
cd "${my_dir}" || { printf %s\\n "Could not cd into project dir" >&2; exit 1; }
my_dir="$( pwd -P; printf a )"; my_dir="${my_dir%?a}"


ARCHIVER="../yt-archive/archive.sh"
CHANNEL_ID='UCWPKJM4CT6ES2BrUz9wbELw'
YOUTUBE_URL="https://youtube.com/channel/${CHANNEL_ID}"
SAMPLE_SIZE='123'

# Greater Project
FRONTEND="../ablc-main"
PUBLIC="../docs/a-bas-le-ciel" # dir to which to write files
PUBLIC_DOMAIN="/a-bas-le-ciel"

# Data Directories (This project)
INTERIMD="../ablc-data/download"
METADATA="../ablc-data/metadata"
SUBTITLE="../ablc-data/subtitle"
DATA_PUBLISHED="../ablc-data/final"
MAIN_PUBLISHED="../ablc-main/final"
DATABASE="../ablc-data/archive.txt"

main() {
  FORCE=""
  my_make "$@"
}



# run: sh % archive-rss
# run: sh % sample-to-frontend
#run: sh % build-frontend-local
my_make() {
  case "${1}"
    in all)
    ;; update)  #git fetch channel

    ;; download-rss)
      errln "=== 1: Download updates by rss ==="
      must_be_in_branch "data"
      "${ARCHIVER}" archive-by-rss "${CHANNEL_ID}" "${INTERIMD}" "${METADATA}" || exit "$?"
    ;; download-channel)
      errln "=== 1: Download updates by channel ==="
      must_be_in_branch "data"
      "${ARCHIVER}" archive-by-channel "YOUTUBE_URL" "${INTERIMD}" ./archive.txt || exit "$?"

    ;; add-to-archive)
      errln "=== 2: Finalising archive ==="
      must_be_in_branch "data"

      info1="$( "${ARCHIVER}" list-stems "${METADATA}" | wc -l )"
      subs1="$( "${ARCHIVER}" list-stems "${SUBTITLE}" | wc -l )"

      "${ARCHIVER}" add-to-archive "${INTERIMD}" "${METADATA}" "${SUBTITLE}" \
        >/dev/null || exit "$?"
      info2="$( "${ARCHIVER}" list-stems "${METADATA}" | wc -l )"
      subs2="$( "${ARCHIVER}" list-stems "${SUBTITLE}" | wc -l )"

      "${ARCHIVER}" add-missing-subs "${INTERIMD}" "${METADATA}" "${SUBTITLE}" \
        || exit "$?"
      "${ARCHIVER}" add-to-archive "${INTERIMD}" "${METADATA}" "${SUBTITLE}" \
        >/dev/null || exit "$?"
      subs3="$( "${ARCHIVER}" list-stems "${SUBTITLE}" | wc -l )"

      errln "Archive before: ${info1} metadata entries and ${subs1} subtitle files"
      errln "Added:" \
        " - $(( info2 - info1 )) metadata entries," \
        " - $(( subs2 - subs1 )) youtube auto-subtitles" \
        " - $(( subs3 - subs2 )) ai auto-subtitles" \
      errln "Archive after:  ${info3} metadata entries and ${subs3} subtitle files"

      errln "" "Compiling 'metadata.json', 'subtitle.json', and 'playlists.json'"
      <parse-info.mjs node - "${METADATA}" "${DATA_PUBLISHED}/metadata.json"
      <parse-subs.mjs node - "${SUBTITLE}" "${DATA_PUBLISHED}/subtitle.json"
      "${ARCHIVER}" download-playlist-list "${YOUTUBE_URL}" >"${DATA_PUBLISHED}/playlist.json"

    ;; sample-to-frontend)
      errln "=== 3: Copying a sample up to ${SAMPLE_SIZE} entries ==="
      must_be_in_branch "data"

      jq "[limit(${SAMPLE_SIZE}; .[])]" "${DATA_PUBLISHED}/metadata.json" \
        >"${MAIN_PUBLISHED}/metadata.json"
      jq "[limit(${SAMPLE_SIZE}; .[])]" "${DATA_PUBLISHED}/subtitle.json" \
        >"${MAIN_PUBLISHED}/subtitle.json"
      cp "${DATA_PUBLISHED}/playlist.json" "${MAIN_PUBLISHED}/playlist.json"

    ;; copy-to-frontend)
      errln "=== 3: Copy all data to frontend ==="
      must_be_in_branch "data"

      cp "${DATA_PUBLISHED}/metadata.json" "${MAIN_PUBLISHED}/metadata.json"
      cp "${DATA_PUBLISHED}/subtitle.json" "${MAIN_PUBLISHED}/subtitle.json"
      cp "${DATA_PUBLISHED}/playlist.json" "${MAIN_PUBLISHED}/playlist.json"

    ;; build-frontend)
      errln "=== 4: Building public directory for server ==="
      must_be_in_branch "main"

      mkdir -p "${PUBLIC}"
      node build.mjs \
        "${MAIN_PUBLISHED}/metadata.json" \
        "${MAIN_PUBLISHED}/playlist.json" \
        "${PUBLIC}" \
        "${PUBLIC_DOMAIN}" \
        "${MAIN_PUBLISHED}/subtitle.json" \
        ${FORCE} || exit "$?"

    ;; build-frontend-local)
      errln "=== 4: Building public directory for local development ==="
      must_be_in_branch "main"

      mkdir -p "${PUBLIC}"
      domain="$( realpath -P "${PUBLIC}"; printf a )"; domain="${domain%?a}"
      node "${FRONTEND}/build.mjs" \
        "${MAIN_PUBLISHED}/metadata.json" \
        "${MAIN_PUBLISHED}/playlist.json" \
        "${PUBLIC}" \
        "${domain}" \
        "${MAIN_PUBLISHED}/subtitle.json" \
        ${FORCE} || exit "$?"

    ;; help|*)  show_help
  esac
}

must_be_in_branch() {
  [ "$( git symbolic-ref -q HEAD )" = "refs/heads/${1}" ] \
    || die FATAL 1 "Only download in 'data' branch"
}

errln() { printf %s\\n "$@" >&2; }
die() { printf %s "${1}: " >&2; shift 1; printf %s\\n "$@" >&2; exit "${1}"; }

main "$@"
