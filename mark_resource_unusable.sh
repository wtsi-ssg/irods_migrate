#!/bin/bash

# Sets the freespace value to same as disk size to mark a resource as
# unusable on a named resource hosted locally on an iRES.

# The minimum_free_space_for_create_in_bytes resource context is set
# to the amount of disk space of the filesystem

# Needs to be run by a user with rodsadmin.

# Copyright (C) 2019,2021 Genome Research Limited
# 
# Author: John Constable <jc18@sanger.ac.uk> (Python implementation)
# Author: Matthew Vernon <mv3@sanger.ac.uk> (Bash version)
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

# Prefix to prepend to resource name to get filesystem path
# default is /
# set with PATHPREFIX environment variable
prefix="${PATHPREFIX:-/}"

# Must run as a rodsadmin user
if [ ! -O /etc/irods/server_config.json ]; then
    echo "Must be run as the rodsadmin user"
    exit 1
fi
if [ "$#" -ne 1 ]; then
    echo "usage: mark_resource_unusable.sh RESOURCENAME"
    exit 1
fi

irodsdir="${prefix}$1"

#Calculate filesystem size by asking stat for the block count * size
#Which is a bash arithmetic expression
if [ -d "$irodsdir" ]; then
    dirsize=$(( $(stat -f --format='%b*%S' "$irodsdir") ))
    echo "Setting minimum free space for $1 to $dirsize bytes"
    iadmin modresc "$1" context "minimum_free_space_for_create_in_bytes=$dirsize"
else
    echo "path $irodsdir for resource $1 is not a directory"
    exit 1
fi
