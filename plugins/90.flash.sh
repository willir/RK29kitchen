#!/bin/bash
#set -vx

MenuAdd "Flashing update to tablet" "flash_Main"

flash_Process(){
	pushd "$WORKDIR" >/dev/null

	SystemUmount

	rkcrc -p parameter parm.img

	echo "Flashing IDB"
	${SUDO} rkflashtool w 0x0 0x20 < parm.img
	${SUDO} rkflashtool w 0x20 0x20 < parm.img
	${SUDO} rkflashtool w 0x40 0x20 < parm.img
	${SUDO} rkflashtool w 0x60 0x20 < parm.img
	${SUDO} rkflashtool w 0x80 0x20 < parm.img
	PARAMFILE="parameter"
	parameter_Parse

	sz=${#SECTION[@]}
	for (( n=0; n<${#SECTION[@]}; n++ ))
	do
		sname=${SECTION[$n]}
		if [ "$sname" == "user" ]
		then
			continue
		fi

		ssize=${SSIZE[$n]}
		sstart=${SSTART[$n]}
		send=$[$sstart+$ssize]
		send=$(printf 0x%08x $send)

		case $sname in
			"boot" | "kernel" | "misc" | "recovery" | "system" )
				cmd=`printf "rkflashtool w 0x%08x 0x%08x " ${sstart} ${ssize}`
				echo "Flashing ${sname} ($sstart - $send)"
				${SUDO} $cmd < Image/${sname}.img
				;;
			"backup" )
				cmd=`printf "rkflashtool w 0x%08x 0x%08x " ${sstart} ${ssize}`
				echo "Flashing ${sname} ($sstart - $send)"
				${SUDO} $cmd < update.img.tmp
				;;
			"cache" | "kpanic" | "userdata" )
				cmd=`printf "rkflashtool e 0x%08x 0x200 " ${sstart}`
				echo "Erase ${sname} ($sstart - $send)"
				${SUDO} $cmd
				;;
		esac
	done
	${SUDO} rkflashtool b


	popd >/dev/null
}

flash_Dump(){
	mkdir -p flashdump/Image 2>/dev/null
	cd flashdump
	WORKDIR=$(pwd)


	${SUDO} rkflashtool r 0 1 >parm.img
	mkkrnlimg -r parm.img parameter

	PARAMFILE="parameter"
	parameter_Parse

	sz=${#SECTION[@]}
	for (( n=0; n<${#SECTION[@]}; n++ ))
	do
		sname=${SECTION[$n]}
		ssize=${SSIZE[$n]}
		sstart=${SSTART[$n]}
		if [ ${sname} == "user" ]
		then
			continue
		fi
		cmd=`printf "rkflashtool r 0x%08x 0x%08x " ${sstart} ${ssize}`
		case $sname in
			"boot" | "kernel" | "misc" | "recovery" | "system" )
				echo "Dumping ${sname} ($cmd)"
				${SUDO} $cmd > Image/${sname}.img 2>>${LOGFILE}
				;;
			"backup" )
				echo "Dumping ${sname} ($cmd)"
				${SUDO} $cmd > ${sname}.img 2>>${LOGFILE}
				;;
			"cache" | "kpanic" | "userdata" | "user" )
				;;
                        *)
                                echo OOPS $sname
                                ;;
		esac
	done
}

flash_Main(){
	if [ "${WORKMODE}" != "In progress" ]
	then
		dialogUnpackFW
		return
	fi

	if [ -z "${BOOTLOADER}" ]
	then
		bootloader_ParseBL
	fi

	if [ $MADEIMAGE -eq 0 ]
	then
		makeUpdateImage_Process
	fi

	dialogOK "Power off you tablet.\nPress the VOL- button and connect usb cable to PC and tablet\nRelease button"

	${SUDO} rkflashtool r 0x0 0xa0 >"$tempfile"
	s=$(stat -c%s "$tempfile")
	if [ $s -ne 81920 ]
	then
		dialogOK "Tablet is not ready"
		return
	fi
	dialogYN "The tablet firmware will be flashed. Exit?"
	case $? in
		0)
			return
			;;
	esac

	flash_Process
}

