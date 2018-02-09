#!/bin/bash
###############################################################################
# Copyright (C) 2007-2010 Lawrence Livermore National Security, LLC.
# Copyright (C) 2007 The Regents of the University of California.
# Produced at Lawrence Livermore National Laboratory (cf, DISCLAIMER).
# Written by Brian Behlendorf <behlendorf1@llnl.gov>.
# UCRL-CODE-235197
#
# This file is part of the SPL, Solaris Porting Layer.
# For details, see <http://zfsonlinux.org/>.
#
# The SPL is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# The SPL is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with the SPL.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################
# This script runs the full set of regression tests.
###############################################################################

prog=check.sh
spl_module=spl
splat_module=splat
splat_cmd=/usr/sbin/splat

#
#  The following subset work in a timely way and don't time out
#  when running inside a VM with < 4GB of memory
#
SPLAT_TESTS=\
"kmem:kmem_alloc kmem:kmem_zalloc kmem:vmem_alloc "\
"kmem:vmem_zalloc kmem:slab_small "\
"kmem:slab_reap kmem:slab_age "\
"kmem:slab_lock taskq:single taskq:multiple "\
"taskq:system taskq:wait taskq:front taskq:recurse "\
"taskq:contention taskq:delay taskq:cancel taskq:dynamic "\
"krng:all mutex:all condvar:all thread:all rwlock:all "\
"time:all vnode:all kobj:all atomic:all list:all "\
"generic:all cred:all zlib:all linux:all"

memtotal=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
if [ ! -z $memtotal ]; then
        if [ $memtotal -gt 4194304 ]; then
		SPLAT_TESTS="kmem:slab_large kmem:slab_align $SPLAT_TESTS"
        fi
fi

tests=""
for t in ${SPLAT_TESTS}
do
        tests="${tests} -t $t"
done

die() {
	echo "${prog}: $1" >&2
	exit 1
}

warn() {
	echo "${prog}: $1" >&2
}

if [ $(getconf LONG_BIT) != 64 ]; then
	echo "Skipping test, only valid for 64 bit architectures"
	exit 0
fi

if [ -n "$V" ]; then
	verbose="-v"
fi

if [ $(id -u) != 0 ]; then
	die "Must run as root"
fi

if /sbin/lsmod | egrep -q "^spl|^splat"; then
	die "Must start with spl modules unloaded"
fi

#if [ ! -f ${spl_module} ] || [ ! -f ${splat_module} ]; then
#	die "Source tree must be built, run 'make'"
#fi

/sbin/modprobe zlib_inflate &>/dev/null
/sbin/modprobe zlib_deflate &>/dev/null

echo "Loading ${spl_module}"
/sbin/modprobe ${spl_module} || die "Failed to load ${spl_module}"

echo "Loading ${splat_module}"
/sbin/modprobe ${splat_module} || die "Unable to load ${splat_module}"

# Wait a maximum of 3 seconds for udev to detect the new splatctl 
# device, if we do not see the character device file created assume
# udev is not running and manually create the character device.
for i in `seq 1 50`; do
	sleep 0.1

	if [ -c /dev/splatctl ]; then
		break
	fi

	if [ $i -eq 50 ]; then
		mknod /dev/splatctl c 229 0
	fi
done

$splat_cmd --nocolor $tests $verbose

echo "Unloading ${splat_module}"
/sbin/modprobe -r ${splat_module} || die "Failed to unload ${splat_module}"

echo "Unloading ${spl_module}"
/sbin/modprobe -r ${spl_module} || die "Unable to unload ${spl_module}"

exit 0
