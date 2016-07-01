#!/bin/bash

# Immediately exit if not called by init system
if [ "X$1" != "Xstart" ]; then
	exit 1
fi

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Log=/var/log/firstboot.log


collect_information() {
	# get some info about the board
	DISTRIBUTION=$(lsb_release -cs)
	case ${DISTRIBUTION} in
		*)
			ROOTFS=$(findmnt / | awk -F" " '/\/dev\// {print $2"\t"$3}')
			set ${ROOTFS}
			root_partition=$1
			rootfstype=$2
			;;
	esac
} # collect_information

display_alert() {
	echo -e " * ${1}" > /dev/tty1
}

do_expand_rootfs() {
	# get device node for boot media
	DEVICE="/dev/"$(lsblk -idn -o NAME | grep -w xvda)
	if [ "${DEVICE}" = "/dev/" ]; then return ; fi

	QUOTED_DEVICE=$(echo "${DEVICE}" | sed 's:/:\\\/:g')
	
	# get count of partitions and their boundaries
	PARTITIONS=$(( $(grep -c ${DEVICE##*/}p /proc/partitions) ))
	PARTSTART=$(parted ${DEVICE} unit s print -sm | tail -1 | cut -d: -f2 | sed 's/s//') # start of first partition
	PARTEND=$(parted ${DEVICE} unit s print -sm | head -3 | tail -1 | cut -d: -f3 | sed 's/s//') # end of first partition
	STARTFROM=$(( ${PARTEND} + 1 ))
	LASTSECTOR=$(( 32 * $(parted ${DEVICE} unit s print -sm | awk -F":" "/^${QUOTED_DEVICE}/ {printf (\"%0d\", ( \$2 * 100 / 3200))}") -1 ))
	[[ ${PARTITIONS} == 1 ]] && STARTFROM=${PARTSTART}

	# Start resizing
	echo -e "\n### [firstrun]. Start resizing Partition now:\n" >>${Log}
	cat /proc/partitions >>${Log}
	echo -e "\nExecuting fdisk, fsck and partprobe:" >>${Log}

	UtilLinuxVersion=$(echo q | fdisk ${DEVICE} | awk -F"util-linux " '/ fdisk / {print $2}')
	if [ "X${PARTITIONS}" = "X1" ]; then
		case ${UtilLinuxVersion} in
			2.27.1*)
				# if dealing with fdisk from util-linux 2.27.1 we need a workaround for just 1 partition
				# https://github.com/igorpecovnik/lib/issues/353#issuecomment-224728506
				((echo d; echo n; echo p; echo ; echo $STARTFROM; echo ${LASTSECTOR} ; echo w;) | fdisk ${DEVICE}) >>${Log} 2>&1 || true
				;;
			*)
				((echo d; echo $PARTITIONS; echo n; echo p; echo ; echo $STARTFROM; echo ${LASTSECTOR} ; echo w;) | fdisk ${DEVICE}) >>${Log} 2>&1 || true
				;;
		esac
	else
		((echo d; echo $PARTITIONS; echo n; echo p; echo ; echo $STARTFROM; echo ${LASTSECTOR} ; echo w;) | fdisk ${DEVICE}) >>${Log} 2>&1 || true
	fi

	fsck -f $root_partition >>${Log} 2>&1 || true
	partprobe ${DEVICE} >>${Log} 2>&1
	echo -e "\nNew partition table:\n" >>${Log}
	cat /proc/partitions >>${Log}
	echo -e "\nNow executing resize2fs to enlarge ${root_partition} to the maximum:\n" >>${Log}
	resize2fs $root_partition >>${Log} 2>&1 || true

	return 0
} # do_expand_rootfs

check_prerequisits() {
	for needed_tool in fdisk parted partprobe resize2fs ; do
		which ${needed_tool} >/dev/null 2>&1 || exit 1
	done
} # check_prerequisits

main() {
  check_prerequisits
	collect_information

	if [ -r "/usr/local/bin/prep_server.sh" ]; then
		rm -f "/usr/local/bin/prep_server.sh"
	fi

	if [ -r "/usr/local/bin/domu-hostname.sh" ]; then
		/bin/bash /usr/local/bin/domu-hostname.sh
		rm -f /usr/local/bin/domu-hostname.sh
	fi

	if [ -r "/usr/local/bin/generate-sshd-keys.sh" ]; then
		/bin/bash /usr/local/bin/generate-sshd-keys.sh
		rm -f /usr/local/bin/generate-sshd-keys.sh
	fi

	if [[ "$rootfstype" == "ext4" && ! -f "/root/.no_rootfs_resize" ]]; then
		display_alert "Resizing root filesystem."
		do_expand_rootfs
	fi

	/bin/systemctl disable firstboot >/dev/null 2>&1
	rm -f /lib/systemd/system/firstboot.service
	rm -f /usr/local/bin/firstboot.sh
} # main

main

