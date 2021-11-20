#/bin/sh

my_dir="$( dirname "${0}"; printf a )"; my_dir="${my_dir%?a}"
cd "${my_dir}" || exit "$?"

git fetch origin main
git show origin/main:make.sh | sh -s "$@"

