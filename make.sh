#!/bin/sh

NAME="$( basename "${0}"; printf a )"; NAME="${NAME%?a}"

show_help() {
  printf %s\\n "SYNOPSIS" >&2
  printf %s\\n "  ${NAME} <JOB> [<arg> ...]" >&2


  printf %s\\n "" "JOBS" >&2
  <"${NAME}" awk '
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
PUBLIC_DOMAIN="/a-bas-le-ciel"

# Data Directories (This project)
INTERIMD="../ablc-data/download"
METADATA="../ablc-data/metadata"
SUBTITLE="../ablc-data/subtitle"
DATA_PUBLISHED="../ablc-data/static"
MAIN_PUBLISHED="../ablc-main/static"
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
    ;; update-data-environment)
      errln "=== 0: Update the main branch ==="
      must_be_in_branch "data"
      pip3 install --upgrade youtube-dl
      git fetch origin main

    ;; download-rss)
      errln "=== 1: Download updates by rss ==="
      git fetch origin main
      must_be_in_branch "data"
      mkdir -p "${INTERIMD}" "${METADATA}" "${SUBTITLE}"
      "${ARCHIVER}" archive-by-rss "${CHANNEL_ID}" "${INTERIMD}" "${METADATA}" || exit "$?"
    ;; download-channel)
      errln "=== 1: Download updates by channel ==="
      git fetch origin main
      must_be_in_branch "data"
      mkdir -p "${INTERIMD}" "${METADATA}" "${SUBTITLE}"
      "${ARCHIVER}" archive-by-channel "${YOUTUBE_URL}" "${INTERIMD}" ./archive.txt || exit "$?"

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

      mkdir -p "${MAIN_PUBLISHED}"
      jq "[limit(${SAMPLE_SIZE}; .[])]" "${DATA_PUBLISHED}/metadata.json" \
        >"${MAIN_PUBLISHED}/metadata.json"
      jq "[limit(${SAMPLE_SIZE}; .[])]" "${DATA_PUBLISHED}/subtitle.json" \
        >"${MAIN_PUBLISHED}/subtitle.json"
      cp "${DATA_PUBLISHED}/playlist.json" "${MAIN_PUBLISHED}/playlist.json"

    ;; copy-to-frontend)
      errln "=== 3: Copy all data to frontend ==="
      must_be_in_branch "data"

      mkdir -p "${MAIN_PUBLISHED}"
      cp "${DATA_PUBLISHED}/metadata.json" "${MAIN_PUBLISHED}/metadata.json"
      cp "${DATA_PUBLISHED}/subtitle.json" "${MAIN_PUBLISHED}/subtitle.json"
      cp "${DATA_PUBLISHED}/playlist.json" "${MAIN_PUBLISHED}/playlist.json"

    ;; build-frontend)  # <output-public-dir>
      errln "=== 4: Building public directory for server ==="
      [ -f "${2}" ] && die FATAL 1 "Arg two '${2}' must be a directory"
      # ${2}: "../public/a-bas-le-ciel", dir to which to write files
      must_be_in_branch "main"

      mkdir -p "${2}"
      node build.mjs \
        "${MAIN_PUBLISHED}/video.json" \
        "${MAIN_PUBLISHED}/playlist.json" \
        "${2}" \
        "${PUBLIC_DOMAIN}" \
        "${MAIN_PUBLISHED}/transcripts.json" \
        ${FORCE} || exit "$?"

    ;; build-frontend-local)
      errln "=== 4: Building public directory for local development ==="
      [ -f "${2}" ] && die FATAL 1 "Arg two '${2}' must be a directory"
      # ${2}: "../public/a-bas-le-ciel", dir to which to write files
      must_be_in_branch "main"

      mkdir -p "${2}"
      domain="$( realpath -P "${2}"; printf a )"; domain="${domain%?a}"
      node "${FRONTEND}/build.mjs" \
        "${MAIN_PUBLISHED}/metadata.json" \
        "${MAIN_PUBLISHED}/playlist.json" \
        "${2}" \
        "${domain}" \
        "${MAIN_PUBLISHED}/subtitle.json" \
        ${FORCE} || exit "$?"

    ############################################################################
    # Utils
    ;; check-overlaps) # Validate we aren't downloading archived videos again
      for id in $( "${ARCHIVER}" list-stems "${INTERIMD}" ); do
        [ -e "${METADATA}/${id}.info.json" ] \
          && errln "Video '${id}' is already in archive"
      done

    ;; test)
      for id in $( "${ARCHIVER}" list-stems "${METADATA}" ); do
        echo "done" >"${INTERIMD}/${id}"
      done
    ;; help|*)  errln "Invalid command '${1}'"; show_help

  esac
}

must_be_in_branch() {
  [ "$( git symbolic-ref -q HEAD )" = "refs/heads/${1}" ] \
    || die FATAL 1 "Must be in the '${1}' branch to do this step"
}

errln() { printf %s\\n "$@" >&2; }
die() { printf %s "${1}: " >&2; shift 1; printf %s\\n "$@" >&2; exit "${1}"; }

main "$@"
