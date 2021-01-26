#!/usr/bin/env python3
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4

# Sets the freespace value to same as disk size to mark a resource as
# unusable on a named resource hosted locally on an iRES.

# The minimum_free_space_for_create_in_bytes resource context is set
# to the amount of disk space of the filesystem

# Needs to be run by a user with rodsadmin.

# Copyright (C) 2019 Genome Research Limited
# 
# Author: John Constable <jc18@sanger.ac.uk>
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

import os
import os.path
import sys
import subprocess
import argparse

IADMIN_CMD = "/usr/bin/iadmin"

def arg_parser():
    parser = argparse.ArgumentParser(
        description='partition/resource to disable via minumum free space')
    parser.add_argument(
        'partition',
        help='partition/resource to disable via minumum free space')

    return parser.parse_args()

def set_min_free_space_for_create(resource):
    resc_path = "/" + resource

    if os.path.isdir(resc_path):
        st = os.statvfs(resc_path)
        size = st.f_frsize * st.f_blocks
        print("setting minimum free space for resource {} to {} bytes...".format(resource, size))
        try:
            ret = subprocess.check_output([IADMIN_CMD, "modresc", resource,
                                          "context",
                                          "minimum_free_space_for_create_in_bytes=%s" % (size)],
                                          stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as E:
            print("Failed! Output:\n{}".format(E.output))
            sys.exit(E.returncode)
    else:
        #alert user thats not a local resource
        print("isdir check failed for vault {} of resource {}".format(resc_path, resource), file=sys.stderr)
        sys.exit(1)


def main():

    set_min_free_space_for_create(arg_parser().partition)

if __name__ == "__main__":
    main()
