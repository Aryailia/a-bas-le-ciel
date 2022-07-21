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
SAMPLE_SIZE='33'

# Greater Project
FRONTEND="../ablc-main"
PUBLIC_DOMAIN="/a-bas-le-ciel"

# Directories from 'data' branch
INTERIMD="./download"
METADATA="./metadata"
SUBTITLE="./subtitle"
DATABASE="./archive.csv"
SKIPFILE="./skipfile.csv"

DATA_PUBLISHED="./publish"

# Directories from 'main' branch
MAIN_PUBLISHED="${FRONTEND}/static"
COMPILED_PUBLISHED="../ablc-compiled"

main() {
  FORCE=''

  # Options processing
  args=''; literal='false'
  for a in "$@"; do
    "${literal}" || case "${a}"
      in --)          literal='true'; continue
      ;; -h|--help)   show_help
      ;; -f|--force)  FORCE='--force'

      ;; -*) die FATAL 1 "Invalid option '${a}'. See \`${NAME} -h\` for help"
      ;; *)  args="${args} $( printf %s\\n "${a}" | eval_escape )"
    esac
    "${literal}" && args="${args} $( outln "${a}" | eval_escape )"
  done

  [ -z "${args}" ] && { show_help; exit 1; }
  eval "set -- ${args}"

  my_make "$@"
}


# run: sh % archive-rss
# run: sh % sample-to-frontend
#run: sh % build-frontend-local
my_make() {
  case "${1}"
    in all)
      die FATAL 1 "WIP commmand"

    ;; update-data-environment)
      errln "=== 0: Update the main branch ==="
      must_be_in_branch "data"
      pip3 install --upgrade youtube-dl
      git fetch origin main

    ;; update-by-rss)
      errln "=== 1: Download updates by rss ==="
      must_be_in_branch "data"
      mkdir -p "${INTERIMD}" "${METADATA}" "${SUBTITLE}"
      "${ARCHIVER}" archive-by-rss "${CHANNEL_ID}" "${INTERIMD}" "${DATABASE}" || exit "$?"
      "${ARCHIVER}" add-to-archive "${INTERIMD}" "${METADATA}" "${SUBTITLE}" || exit "$?"
      "${ARCHIVER}" add-missing-subs "${INTERIMD}" "${METADATA}" "${SUBTITLE}" || exit "$?"
      "${ARCHIVER}" add-to-archive "${INTERIMD}" "${METADATA}" "${SUBTITLE}" || exit "$?"

    ;; update-by-channel)
      errln "=== 1: Download updates by channel ==="
      must_be_in_branch "data"
      mkdir -p "${INTERIMD}" "${METADATA}" "${SUBTITLE}"
      "${ARCHIVER}" archive-by-channel "${YOUTUBE_URL}" "${INTERIMD}" "${DATABASE}" || exit "$?"

      # Not sure why exactly youtube-dl creates this file
      errln "removing '${CHANNEL_ID}.info.json'"
      rm "${METADATA}/${CHANNEL_ID}.info.json"
      "${ARCHIVER}" add-to-archive "${INTERIMD}" "${METADATA}" "${SUBTITLE}" || exit "$?"
      "${ARCHIVER}" add-missing-subs "${INTERIMD}" "${METADATA}" "${SUBTITLE}" || exit "$?"
      "${ARCHIVER}" add-to-archive "${INTERIMD}" "${METADATA}" "${SUBTITLE}" || exit "$?"

    ;; save-update)
      errln "=== 2: Compile, commit, and push updates (if there are any) ==="
      must_be_in_branch "data"

      if [ "$( git status --short | wc -l )" -gt 0 ]; then
        "${ARCHIVER}" list-as-archive "${METADATA}" >"${DATABASE}" || exit "$?"
        git add "${METADATA}" "${SUBTITLE}" "${DATABASE}"
        git commit -m "Update $( date +"%Y-%m-%d" )"
        git push origin data
        my_make compile
      else
        errln "No updates"
      fi

    ;; compile)
      errln "=== 3: Compiling to 'compile' branch ==="
      must_be_in_branch "data"
      mkdir -p "${DATA_PUBLISHED}"

      errln "Compiling metadata.json..."
      git show local/main:parse-metadata.js | node - \
        "${METADATA}" "${SUBTITLE}" "${DATA_PUBLISHED}/metadata.json"
      errln "Compiling playlist.json..."
      "${ARCHIVER}" download-playlist-list "${YOUTUBE_URL}" >"${DATA_PUBLISHED}/playlist.json"

      errln "Pushing to 'compiled' branch"
      # TODO: add check to make sure we can commit

      git branch -D compiled
      commit_hash="$( git rev-parse HEAD )"
      git add "${DATA_PUBLISHED}"
      git commit -m "Publishing on $( date +%Y-%m-%d )" || exit "$?"
      git subtree split --prefix "${DATA_PUBLISHED#*/}" --branch compiled || exit "$?"
      git push --force origin compiled:compiled || exit "$?"
      git reset "${commit_hash}"  # undo the commit for the main branch
      rm -r "${DATA_PUBLISHED}"

    ;; sample-to-frontend)
      errln "=== 6: Copying a sample up to ${SAMPLE_SIZE} entries ==="
      must_be_in_branch "main"

      mkdir -p "${MAIN_PUBLISHED}"
      jq "[limit(${SAMPLE_SIZE}; .[])]" "${COMPILED_PUBLISHED}/metadata.json" \
        >"${MAIN_PUBLISHED}/metadata.json"
      cp "${COMPILED_PUBLISHED}/playlist.json" "${MAIN_PUBLISHED}/playlist.json"

    ;; copy-to-frontend)
      errln "=== 6: Copy all data to frontend ==="
      must_be_in_branch "main"

      mkdir -p "${MAIN_PUBLISHED}"
      cp "${COMPILED_PUBLISHED}/metadata.json" "${MAIN_PUBLISHED}/metadata.json"
      cp "${COMPILED_PUBLISHED}/subtitle.json" "${MAIN_PUBLISHED}/subtitle.json"
      cp "${COMPILED_PUBLISHED}/playlist.json" "${MAIN_PUBLISHED}/playlist.json"

    ;; build-frontend)  # <output-public-dir>
      errln "=== 7: Building public directory for server ==="
      [ -f "${2}" ] && die FATAL 1 "Arg two '${2}' must be a directory"
      # ${2}: "../public/a-bas-le-ciel", dir to which to write files
      must_be_in_branch "main"

      mkdir -p "${2}"
      node build.mjs \
        "${MAIN_PUBLISHED}/metadata.json" \
        "${MAIN_PUBLISHED}/playlist.json" \
        "${2}" \
        "${PUBLIC_DOMAIN}" \
        "${MAIN_PUBLISHED}/subtitle.json" \
        ${FORCE} || exit "$?"

    ;; build-frontend-local)
      errln "=== 7: Building public directory for local development ==="
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

    ;; status)
      must_be_in_branch "data"
      #info_count="$( "${ARCHIVER}" list-stems "${METADATA}" | wc -l )"
      #subs_count="$( "${ARCHIVER}" list-stems "${SUBTITLE}" | wc -l )"

      errln "=== Missing subtitles ==="
      count=0
      subs_missing='0'
      for id in $( "${ARCHIVER}" list-stems "${METADATA}" ); do
        count="$(( count + 1 ))"
        if [ ! -e  "${SUBTITLE}/${id}.en.vtt" ]; then 
          errln "  ${id}"
          subs_missing="$(( subs_missing + 1 ))"
        fi
      done

      errln "=== Missing metadata ==="
      info_missing='0'
      for id in $( "${ARCHIVER}" list-stems "${SUBTITLE}" ); do
        if [ ! -e  "${METADATA}/${id}.info.json" ]; then 
          errln "  ${id}"
          info_missing="$(( info_missing + 1 ))"
        fi
      done

      errln "There are $(( count + info_missing )) entries:"
      errln "  ${info_missing} metadata files are missing"
      errln "  ${subs_missing} subtitle files are missing"

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
eval_escape() { <&0 sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/"; }
die() { printf %s "${1}: " >&2; shift 1; printf %s\\n "$@" >&2; exit "${1}"; }


main "$@"
