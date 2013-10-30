#!/bin/bash
#
# blts-filesystem-perf - filesystem performance test suite
#
# Copyright (C) 2013 Jolla Ltd.
# Contact: Martin Kampas <martin.kampas@jollamobile.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 2.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

BONNIE_BIN="/usr/sbin/bonnie++"
[[ -f ${BONNIE_BIN} ]] || { echo "bonnie++ not installed" >&2; exit 1; }

print_help()
{
    cat >&2 <<END
Usage: $(basename "$0") -s summary_file -r raw_file -k key1,key2,...
       [-- [BONNIE++_ARGS...]]

Runs \`bonnie++' with given arguments (if any) and processes its output.

Human readable summary (\`bonnie++ -q' writes this to its stderr) is written
to standard output.

OPTIONS

    -r raw_file
        Write raw \`bonnie++ -q' stdout to this file.

    -s summary_file
        Write values for keys selected with \`-k' switch in format accepted by
        \`testrunner-lite' to this file.

    -k key1,key2,...
        See \`-s'. Possible keys: $(
                declare -F |sed -n 's/.* bonnie_res_\(.*\)/\1/p' |tr '\n' ' ')

END
}

csv()
{
    cut -d, -f$2 <<<"$1"
}

bonnie_result()
{
    VALUE="$(csv "${BONNIE_OUT}" "${1?}")"
    KEY="${FUNCNAME[1]#bonnie_res_}.${2?}"
    UNIT="${3?}"

    echo "${KEY};${VALUE};${UNIT};"
}

bonnie_res_seq_create() { bonnie_result 16 "speed" "files/s"; }
bonnie_res_seq_output() { bonnie_result 3 "speed" "KB/s"; }
bonnie_res_seq_input() { bonnie_result 9 "speed" "KB/s"; }

# Convert output produced by `time -p' so it is suitable for testrunner
time2testrunner()
{
    awk 'NF>0 { printf "total.elapsed.%s;%g;ms;\n", $1, $2 * 1000; }'
}

# Formats output produced by `time -p' as a table with header
time2table()
{
    awk 'BEGIN { print "Time Spent,[s]" } { print $1 "," $2 }' |column -t -s,
}

while getopts "hk:r:s:" OPTNAME "${@}"
do
    case "${OPTNAME}" in
        h)
            print_help
            exit 1
            ;;
        k)
            KEYS=(${OPTARG//,/ })
            ;;
        r)
            RAW_FILE="${OPTARG}"
            ;;
        s)
            SUMMARY_FILE="${OPTARG}"
            ;;
    esac
done

eval FIRST_NON_SWITCH=\$$((OPTIND-1))
[[ -z ${FIRST_NON_SWITCH} || ${FIRST_NON_SWITCH} == "--" ]] || { print_help; exit 1; }
shift $((OPTIND-1))

[[ -n ${KEYS} ]] || { print_help; exit 1; }
[[ -n ${SUMMARY_FILE} ]] || { print_help; exit 1; }
[[ -n ${RAW_FILE} ]] || { print_help; exit 1; }

: >${SUMMARY_FILE}
: >${RAW_FILE}

BONNIE_OUT_FILE="/tmp/bonnie++.stdout"
BONNIE_ERR_FILE="/tmp/bonnie++.stderr"
TIME_FILE="/tmp/run-bonnie++.time"

trap "rm -f ${BONNIE_OUT_FILE} ${BONNIE_ERR_FILE} ${TIME_FILE}" EXIT INT TERM

command time --portability --output=${TIME_FILE} \
    $BONNIE_BIN -q >${BONNIE_OUT_FILE} 2>${BONNIE_ERR_FILE} "${@}" || exit

BONNIE_OUT="$(<${BONNIE_OUT_FILE})"
for key in ${KEYS[*]}
do
    bonnie_res_${key}
done >${SUMMARY_FILE}
cat >${RAW_FILE} ${BONNIE_OUT_FILE}
cat ${BONNIE_ERR_FILE}

# append timing info
time2testrunner <${TIME_FILE} >>${SUMMARY_FILE}
{ echo; time2table; } <${TIME_FILE}
