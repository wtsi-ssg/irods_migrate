#!/bin/bash
#Script to call iphymv with exponential back-off
# Moves one object from SOURCE to DEST
# Call thus:
# irods_backof_move.sh SOURCE DEST object

# Copyright (C) 2020,2021 Genome Research Limited
# 
# Author: Matthew Vernon <mv3@sanger.ac.uk>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

if [ "$#" -ne "3" ]; then
    echo "Usage: irods_backoff_move.sh SOURCE DEST object"
    exit 1
fi

# Must run as a rodsadmin user
if [ ! -O /etc/irods/server_config.json ]; then
    echo "Must be run as the rodsadmin user"
    exit 1
fi

# Function that does the work
phym()
{
for i in $(seq 0 8); do
    # iphymv return value isn't very useful, so inspect stderr
    msg=$(iphymv "$@" 2>&1)
    rv="$?"
    if [ "$rv" -eq 0 ]; then
	if [ "$i" -gt 0 ]; then
	    echo "Took $i retries to do $*"
	fi
	return
    else
	echo "$msg"
	if [[ "$msg" =~ "No space left on device" ]]; then
	    echo "Target full, stopping parallel"
	    # TERM means "do not start any new jobs"
	    kill -TERM "$PARALLEL_PID"
	    return "$rv"
	# checksum mismatch or absent src not worth retrying
	elif [[ "$msg" =~ "USER_CHKSUM_MISMATCH" ]] ||
                 [[ "$msg" =~ srcPath.*does\ not\ exist ]]; then
            return "$rv"
	# Assume other failures are transient, try to backoff
	elif [ "$i" -lt 8 ]; then
	    sleep "$((2**i))"
	else
	    echo "giving up on $*"
	    exit 1
	fi
    fi
done
echo "!!! This code is impossible to reach !!!"
exit 2
}

phym -M -S "$1" -R "$2" "$3"
