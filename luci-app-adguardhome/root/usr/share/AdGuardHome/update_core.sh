#!/bin/sh

PATH="/usr/sbin:/usr/bin:/sbin:/bin"
update_mode=$1
binpath=$(uci get AdGuardHome.AdGuardHome.binpath)
if [[ -z ${binpath} ]]; then
	uci set AdGuardHome.AdGuardHome.binpath="/tmp/AdGuardHome/AdGuardHome"
	binpath="/tmp/AdGuardHome/AdGuardHome"
fi
[[ ! -d ${binpath%/*} ]] && mkdir -p ${binpath%/*}
upxflag=$(uci get AdGuardHome.AdGuardHome.upxflag 2>/dev/null)

[[ -z ${upxflag} ]] && upxflag=off
enabled=$(uci get AdGuardHome.AdGuardHome.enabled 2>/dev/null)
core_version=$(uci get AdGuardHome.AdGuardHome.core_version 2>/dev/null)
update_url=$(uci get AdGuardHome.AdGuardHome.update_url 2>/dev/null)

case "${core_version}" in
beta)
	core_api_url=https://api.github.com/repos/AdguardTeam/AdGuardHome/releases
;;
*)
	core_api_url=https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest
;;
esac

Check_Task(){
	running_tasks="$(ps -efww  | grep -v grep | grep "AdGuardHome" | grep "update_core" | awk '{print $1}' | wc -l)"
	case $1 in
	force)
		echo -e "Execute: Force a core update"
		echo -e "Remove ${running_tasks} process ..."
		ps -efww  | grep -v grep | grep -v $$ | grep "AdGuardHome" | grep "update_core" | awk '{print $1}' | xargs kill -9 2> /dev/null
	;;
	*)
		[[ ${running_tasks} -gt 2 ]] && echo -e "Already have ${running_tasks} tasks are running, Please wait for it to complete or force stop it!" && EXIT 2
	;;
	esac
}

Check_Downloader(){
	which curl > /dev/null 2>&1 && PKG="curl" && return
	echo -e "\nNot installed curl"
	which wget-ssl > /dev/null 2>&1 && PKG="wget-ssl" && return
	echo "Not installed curl and wget, unable to detect updates!" && EXIT 1
}

Check_Updates(){
	Check_Downloader
	case "${PKG}" in
	curl)
		Downloader="curl -L -k -o"
		_Downloader="curl -s"
	;;
	wget-ssl)
		Downloader="wget-ssl --no-check-certificate -T 5 -O"
		_Downloader="wget-ssl -q -O -"
	;;
	esac
	echo "[${PKG}] Start checking for updates, please wait ..."
	Cloud_Version="$(${_Downloader} ${core_api_url} 2>/dev/null | grep 'tag_name' | egrep -o "v[0-9].+[0-9.]" | awk 'NR==1')"
	[[ -z ${Cloud_Version} ]] && echo -e "\nCheck for updates failed, Please check the network or try again later!" && EXIT 1
	if [[ -f ${binpath} ]]; then
		Current_Version="$(${binpath} --version 2>/dev/null | egrep -o "v[0-9].+[0-9]" | sed -r 's/(.*), c(.*)/\1/')"
	else
		Current_Version="unknown"
	fi
	[[ -z ${Current_Version} ]] && Current_Version="unknown"
	echo -e "\nExecutable file path: ${binpath%/*}\n\nChecking for updates, please wait ..."
	echo -e "\nCurrent AdGuard Home version: ${Current_Version}\nThe cloud AdGuard Home version: ${Cloud_Version}"
	if [[ ! "${Cloud_Version}" == "${Current_Version}" || "$1" == force ]]; then
		Update_Core
	else
		echo -e "\nAlready the latest version, no update required!" 
		EXIT 0
	fi
	EXIT 0
}

UPX_Compress(){
	GET_Arch
	upx_name="upx-${upx_latest_ver}-${Arch_upx}_linux.tar.xz"
	echo -e "Starting download ${upx_name} ...\n"
	$Downloader /tmp/upx-${upx_latest_ver}-${Arch_upx}_linux.tar.xz "https://github.com/upx/upx/releases/download/v${upx_latest_ver}/${upx_name}"
	if [[ ! -e /tmp/upx-${upx_latest_ver}-${Arch_upx}_linux.tar.xz ]]; then
		echo -e "\n${upx_name} download failed!\n" 
		EXIT 1
	else
		echo -e "\n${upx_name} download successful!\n" 
	fi
	which xz > /dev/null 2>&1 || (opkg list | grep ^xz || opkg update > /dev/null 2>&1 && opkg install xz --force-depends) || (echo "Package xz installation failed!" && EXIT 1)
	mkdir -p /tmp/upx-${upx_latest_ver}-${Arch_upx}_linux
	echo -e "Unpacking ${upx_name} ...\n" 
	xz -d -c /tmp/upx-${upx_latest_ver}-${Arch_upx}_linux.tar.xz | tar -x -C "/tmp"
	[[ ! -f /tmp/upx-${upx_latest_ver}-${Arch_upx}_linux/upx ]] && echo -e "\n${upx_name} unpacking failed!" && EXIT 1
}

Update_Core(){
	rm -r /tmp/AdGuardHome_Update > /dev/null 2>&1
	mkdir -p "/tmp/AdGuardHome_Update"
	GET_Arch
	eval link="${update_url}"
	echo -e "Download link: ${link}"
	echo -e "File name: ${link##*/}"
	echo -e "\nStarting download AdGuard Home core file ...\n" 
	$Downloader /tmp/AdGuardHome_Update/${link##*/} ${link}
	if [[ $? != 0 ]];then
		echo -e "\n AdGuard Home core download failed ..."
		rm -r /tmp/AdGuardHome_Update
		EXIT 1
	fi 
	if [[ ${link##*.} == gz ]]; then
		echo -e "\nUnpacking AdGuard Home ..."
		tar -zxf "/tmp/AdGuardHome_Update/${link##*/}" -C "/tmp/AdGuardHome_Update/"
		if [[ ! -e /tmp/AdGuardHome_Update/AdGuardHome ]]
		then
			echo "AdGuard Home Core unpacking failed!" 
			rm -rf "/tmp/AdGuardHome_Update" > /dev/null 2>&1
			EXIT 1
		fi
		downloadbin="/tmp/AdGuardHome_Update/AdGuardHome/AdGuardHome"
	else
		downloadbin="/tmp/AdGuardHome_Update/${link##*/}"
	fi
	chmod +x ${downloadbin}
	echo -e "\nAdGuard Home core volume: $(awk 'BEGIN{printf "%.2fMB\n",'$((`ls -l $downloadbin | awk '{print $5}'`))'/1000000}')"
	if [[ ${upxflag} != off ]]; then
		UPX_Compress
		echo -e "Use UPX compression can take a long time, please be patient!\nCompressing $downloadbin ..."
		/tmp/upx-${upx_latest_ver}-${Arch_upx}_linux/upx $upxflag $downloadbin > /dev/null 2>&1
		echo -e "\nCompressed core volume: $(awk 'BEGIN{printf "%.2fMB\n",'$((`ls -l $downloadbin | awk '{print $5}'`))'/1000000}')"
	else
		echo "Not enabled UPX compression, skip operation..."
	fi
	/etc/init.d/AdGuardHome stop > /dev/null 2>&1
	echo -e "\nMove AdGuard Home core file to ${binpath%/*} ..."
	mv -f ${downloadbin} ${binpath} > /dev/null 2>&1
	if [[ ! -s ${binpath} && $? != 0 ]]; then
		echo -e "AdGuard Home core move failed!\nIt may be caused by insufficient space on the device, please try to enable UPX compression, or change [executable file path] for /tmp/AdGuardHome" 
		EXIT 1
	fi
	rm -f /tmp/upx*.tar.xz
	rm -rf /tmp/upx*	
	rm -rf /tmp/AdGuardHome_Update
	chmod +x ${binpath}
	if [[ ${enabled} == 1 ]]; then
		echo -e "\nRestarting AdGuard Home service..."
		/etc/init.d/AdGuardHome restart
	fi
	echo -e "\nAdGuard Home core update successful!" 
}

GET_Arch() {
	Archt="$(opkg info kernel | grep Architecture | awk -F "[ _]" '{print($2)}')"
	case "${Archt}" in
	i386)
		Arch=i386
	;;
	i686)
		Arch=i386
	;;
	x86)
		Arch=amd64
	;;
	mipsel)
		Arch=mipsle_softfloat
	;;
	mips)
		Arch=mips_softfloat
	;;
	mips64el)
		Arch=mips64le_softfloat
	;;
	mips64)
		Arch=mips64_softfloat
	;;
	arm)
		Arch=arm
	;;
	armeb)
		Arch=armeb
	;;
	aarch64)
		Arch=arm64
	;;
	*)
		echo -e "\nAdGuard Home the current device architecture is not currently supported: [${Archt}]!" 
		EXIT 1
	esac
	case "${Archt}" in
	mipsel)
		Arch_upx="mipsel"
		upx_latest_ver="3.95"
	;;
	*)
		Arch_upx="${Arch}"
		upx_latest_ver="$(${_Downloader} https://api.github.com/repos/upx/upx/releases/latest 2>/dev/null | egrep 'tag_name' | egrep '[0-9.]+' -o 2>/dev/null)"
	
	esac
	echo -e "\nCurrent device architecture: ${Arch}\n"
}

EXIT(){
	rm -rf /var/run/update_core $LOCKU 2>/dev/null
	[[ $1 != 0 ]] && touch /var/run/update_core_error
	exit $1
}

main(){
	Check_Task ${update_mode}
	Check_Updates ${update_mode}
}

trap "EXIT 1" SIGTERM SIGINT
touch /var/run/update_core
rm - rf /var/run/update_core_error 2>/dev/null

main
