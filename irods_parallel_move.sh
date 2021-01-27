#!/bin/bash
# Script to move all the objects from resource to another;
# resources are outside the main tree while this is done.
# Process is:
# 1) move SOURCE and DEST out of resource tree
# 2) parallel-iphymv objects from SOURCE to DEST
# 3) move SOURCE and DEST back to where they were

# Control parallelisation with the value of ~/.parallel-num
# Have irods_backoff_move.sh in pwd.

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

set -e
set -o pipefail

# Set the CONTINUE env-var to any non-empty value if you want the dest
# resource left out-of-tree when migration is completed (e.g. because
# you want to move a second resource there)
if [ -n "$CONTINUE" ]; then
    cont="true"
else
    cont="false"
fi

# Where to put orphan resources when finished
# set with the ORPHANHOME environment variable
orphan_home="${ORPHANHOME:-green7}"

# Must run as a rodsadmin user
if [ ! -O /etc/irods/server_config.json ]; then
    echo "Must be run as the rodsadmin user"
    exit 1
fi
if [ "$#" -ne 2 ]; then
    echo "usage: irods_parallel_move.sh SOURCE DEST"
    exit 1
fi
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Both resources must be non-empty strings!"
    exit 1
fi
if [ ! -s ~/.parallel-num ]; then
    echo "Put the number of parallel writes you want into ~/.parallel-num"
    exit 1
fi
if [ ! -x irods_backoff_move.sh ]; then
    echo "irods_backoff_move.sh must be extant and executable in ."
    exit 1
fi

# check SOURCE resource is closed to writes;
# the check is that minimum_free_space_for_create_in_bytes should be
# greater or equal to resource_size (which is in 1k blocks)
mfs_cib=$(ilsresc -l "$1" | sed -ne 's/^context: minimum_free_space_for_create_in_bytes=//p')
res_size=$(imeta ls -R "$1" resource_size | sed -ne 's/value: //p')
if [ "$((mfs_cib / 1024))" -lt "$((res_size - 1))" ]; then
    echo "SOURCE resource $1 should be closed using mark_resource_unusable.sh"
    exit 1
fi

find_parent()
{
    if [ "$#" -ne 1 ] || [ -z "$1" ]; then
	echo "Internal error - find_parent needs 1 non-empty argument"
	exit 2
    fi
    parid=$(ilsresc -l "$1" | sed -ne 's/^parent: //p')
    if [ -z "$parid" ]; then
	echo "orphan"
	return
    fi
    # https://github.com/irods/irods/issues/5069
    par=$(iquest "SELECT RESC_NAME WHERE RESC_ID = '$parid'" | sed -ne 's/^RESC_NAME = //p')
    echo "$par"
}

# Called if something goes wrong.
clearup()
{
    rm -f "$listpath"
    echo "Something went wrong; the log of resources and parents is $log"
    echo "The parallel log is $parlog"
    echo -n "If you want to re-try, "
    if [ "$cont" = "false" ]; then
	echo "put resources back into the tree first:"
	echo "iadmin addchildtoresc $dr_parent $dr"
    else
	echo "put the source resource back into the tree first:"
    fi
    echo "iadmin addchildtoresc $sr_parent $sr"
}

sr="$1"
dr="$2"

sr_parent=$(find_parent "$sr")
dr_parent=$(find_parent "$dr")

log=$(mktemp ~/parallelmovelog_XXXXXX)
trap clearup ERR
echo "Log file is $log"

echo "$sr_parent is parent of source $sr" >>"$log" 
echo "$dr_parent is parent of dest $dr" >>"$log" 
if [ "$cont" = "true" ]; then
    echo "CONTINUE specified, will leave dest out of tree" >> "$log"
    echo "CONTINUE specified, will leave dest out of tree at end"
fi

echo "Removing source and destination resources from tree"
iadmin rmchildfromresc "$sr_parent" "$sr"
if [ "$dr_parent" = "orphan" ]; then
    # If CONTINUE set, dest is left out of tree at the end
    if [ "$cont" = "false" ]; then
	echo "(destination was orphan, will put into $orphan_home at end)"
	dr_parent="$orphan_home"
	echo "$dr was orphan will put into $dr_parent at end" >> "$log"
    fi
else
    iadmin rmchildfromresc "$dr_parent" "$dr"
fi

echo "Building list of objects"
listpath=$(mktemp)
iquest --no-page "%s/%s" "select COLL_NAME, DATA_NAME where DATA_RESC_NAME = '${sr}'" > "$listpath"

parlog=$(mktemp)
echo "Parallel logfile is $parlog"
parallel --bar --halt soon,fail=99 --joblog "$parlog" -j ~/.parallel-num ./irods_backoff_move.sh "$sr" "$dr" '{}' :::: "$listpath"

echo -n "Putting $sr back under $sr_parent"
if [ "$cont" = "false" ]; then
    echo " and $dr back under $dr_parent"
    iadmin addchildtoresc "$dr_parent" "$dr"
else
    echo "."
fi
iadmin addchildtoresc "$sr_parent" "$sr"

rm "$log" "$listpath" "$parlog"
echo "All done"
