#!/bin/bash
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")
myprog=$(basename $0)

function absolutepath()
{
  echo -n "$(cd -P -- "$(dirname -- "$1")" && pwd -P)"
}
#-S ../obj/ETC/file_contexts.bin_intermediates/file_contexts.bin
(cd $1; find . -type d | sed 's,$,/,'; find . \! -type d) | cut -c 3- | sort | sed 's,^,,' | ${SCRIPTPATH}/fs_config -D $2  > $3 
