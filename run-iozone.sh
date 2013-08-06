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

IOZONE="/opt/iozone/bin/iozone"
[[ -f ${IOZONE} ]] || { echo "FIXME: iozone install path changed" >&2; exit 1; }

print_help()
{
    cat >&2 <<END
Usage: $(basename "$0") -s summary_file -r raw_file [-- [IOZONE_ARGS...]]

Runs \`iozone' with given arguments (if any) and processes its output.

Human readable summary (average for each column) is written to standard output.

OPTIONS

    -r raw_file
        Write raw \`iozone' output to this file.

    -s summary_file
        Write summary (average for each column) in format accepted by
        \`testrunner-lite' to this file.

END
}

# Read a table of numbers and compute average of values in given column
avg_column()
{
    awk -v COL=${1?} '$COL { sum+=$COL; cnt++; } END { printf "%d", (cnt ? int(sum/cnt) : 0) }'
}

# Read iozone output and report average for each column
summary()
{
    INPUT="$(awk '$1 ~ /^[0-9]+/ { print }')"

    OPS=(write rewrite read reread randread randwrite bkwdread recrewrite strideread fwrite frewrite
            fread freread)

    {
        echo "Operation,AVG Speed [KB/s]"
        for ((i=0; i<${#OPS[*]}; i++))
        do
            AVG="$(avg_column $((i+3)) <<<"${INPUT}")"
            echo "${OPS[i]},${AVG}"
        done
    } |column -t -s,
}

# Convert output produced by summary() so it is suitable for testrunner
summary2testrunner()
{
    awk 'NR>1 { printf "%s.avg_speed;%d;KB/s;\n", $1, $2; }'
}

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

while getopts "hr:s:" OPTNAME "${@}"
do
    case "${OPTNAME}" in
        h)
            print_help
            exit 1
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

[[ -n ${SUMMARY_FILE} ]] || { print_help; exit 1; }
[[ -n ${RAW_FILE} ]] || { print_help; exit 1; }

TIME_FILE="/tmp/run-iozone.time"

set -o errexit -o pipefail
trap "rm -f ${TIME_FILE}" EXIT INT TERM

command time --portability --output=${TIME_FILE} \
  ${IOZONE} "${@}" |tee ${RAW_FILE} |summary |tee >(summary2testrunner >${SUMMARY_FILE})

# append timing info
time2testrunner <${TIME_FILE} >>${SUMMARY_FILE}
{ echo; time2table; } <${TIME_FILE}
