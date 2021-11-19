#/bin/sh

my_dir="$( dirname "${0}"; printf a )"; my_dir="${my_dir%?a}"
cd "${my_dir}" || exit "$?"

git show main:make.sh | sh -s "$@"

