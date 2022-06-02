#!/usr/bin/env bash

#====================================================
# YAPManTool Updater
# (c) 2022 Nathan "nwb99" Barnett, see LICENSE
# version 0.1
#
#
#
#
#
#====================================================


#TODO
# ERROR HANDLING. check every exit for error handling
# LOGGING
# COMMENTS
# LIST RECENT BUILDS/VERSIONS W/ CHANGELOGS
# check if Paper is running
# DONE - shasum
# get current paper jar build
# dont overwrite current file. mv to paper-old.jar. if shasum is the same, exit
# script update checker

if [ "$(id -u)" -eq 0 ]
then
	echo "do not run this script as root"
	exit 1
fi


paper_jar="paper.jar"
paper_path="."
paper_api="https://papermc.io/api/v2"
paper_builds="paper_builds.json"
paper_builds_ext="paper_builds_ext.json"
paper_versions="paper_versions.json"
download_url="${paper_api}/projects/paper/versions/${paper_ver}/builds/${build}/downloads/paper-${paper_ver}-${build}.jar"

prog_name="$(basename "${0}")"
formal_name="YAPManTool Updater"

script_ver="0.1"


u_flag=false
b_flag=false
g_flag=false
f_flag=false
no_ver_set=false
force_new_json=false


error_msg() {
	echo -e "${prog_name}: ${1}" >&2
	exit 1
}

error_option() {
	echo -e "option -- '${1}' requires '${2}'"
}

check_reqs() {
	req_progs=(curl jq wget)
	for prog in "${req_progs[@]}"
	do
		if ! command -v "${prog}" > /dev/null 2>&1
		then
			error_msg "missing program '${prog}'\nThis script requires the following programs (and GNU coreutils): ${req_progs[*]}"
		fi
	done
}

check_net() {
	# probably eliminate wget later
	if ! eval "wget -q --spider https://papermc.io"
	then
		error_msg "Could not ping papermc.io\nCheck your network connection."
	fi
}

shasum_f() {
	sha256="$(sha256sum "${paper_path}/${paper_jar}" | cut -d ' ' -f1)"
	expected_sha256="$(curl -sX GET "${paper_api}/projects/paper/versions/${paper_ver}/builds/${build}" | jq -r '.downloads.application.sha256')"

	if [ "${sha256}" != "${expected_sha256}" ]
	then
		error_msg "SHA256 for downloaded Paper jar does not match what is expected."
	else
		echo "SHA256 matches. Done!"
		exit 0
	fi
}

valid_ver() {
	readarray -t versions < <(< ${paper_versions} jq '.versions[]')

	for i in "${versions[@]}"
	do
		if [ "${i}" != "${paper_ver}" ]
		then
			continue
		else
			valid_version=true
			break
		fi
	done

	if ! $valid_version
	then
		error_msg "${paper_ver}: not a valid Paper version"
	fi
}

update() {
	if [ ! -f "${paper_versions}" ] || $force_new_json
	then
		# curl --fail flag isn't foolproof but is probably good enough. 301 redirect, for example returns 0.
		curl --fail -sX GET "${paper_api}/projects/paper/" | jq . > "${paper_versions}"
		if [ ! "${PIPESTATUS[0]}" -eq 0 ]
		then
			if [ ! -s "${paper_versions}" ]
			then
				rm -f "${paper_versions}"	# I want to avoid rm if possible. There's likely a more elegant way.
			fi
			error_msg "curl: API error"
		fi
	fi

	if ( $no_ver_set && [ ! -f "${paper_builds}" ] ) || ( $no_ver_set && $force_new_json )
	then
		paper_ver="$(< ${paper_versions} jq -r '.versions[-1]')"
		curl --fail -sX GET "${paper_api}/projects/paper/versions/${paper_ver}/" | jq . > "${paper_builds}"
		if [ ! "${PIPESTATUS[0]}" -eq 0 ]
		then
			if [ ! -s "${paper_builds}" ]
			then
				rm -f "${paper_builds}"
			fi
			error_msg "curl: API error"
		fi
	fi

	if $no_ver_set
	then
		paper_ver="$(< ${paper_versions} jq -r '.versions[-1]')"
	fi

	if ! $b_flag
	then
		curl -sX GET "${paper_api}/projects/paper/versions/${paper_ver}/" | jq . > "${paper_builds}"
		if [ ! "${PIPESTATUS[0]}" -eq 0 ]
		then
			if [ ! -s "${paper_builds}" ]
			then
				rm -f "${paper_builds}"
			fi
			error_msg "curl: API error"
		fi
		build="$(< ${paper_builds} jq -r '.builds[-1]')"
	else
	 	build="${paper_build}"
	fi

	if [ -s "${paper_path}/${paper_jar}" ] && ! $f_flag
	then
		error_msg "file "${paper_path}/${paper_jar}" already exists.\nUse option '-f' to force download."
	fi
	download_url="${paper_api}/projects/paper/versions/${paper_ver}/builds/${build}/downloads/paper-${paper_ver}-${build}.jar"
	echo "Downloading Paper ${paper_ver} build ${build} to \"${paper_path}/${paper_jar}\""
	curl --create-dirs -o "${paper_path}/${paper_jar}" -L "${download_url}"
	shasum_f
}

cur_build() {
	if [ ! -f "${paper_path}/${paper_jar}" ]
	then
		error_msg "${paper_jar}: no such file"
	fi

	curl -sX GET "${paper_api}/projects/paper/versions/${paper_ver}/builds/" | jq . > "${paper_builds_ext}"
	total_builds="$(( $(< ${paper_builds_ext} jq -r '.builds[].build' | wc -l) - 1 ))"
	sha256="$(sha256sum "${paper_path}/${paper_jar}" | cut -d ' ' -f1)"

	# User is likely to have newer build, so let's count backwards to speed this up.
	for (( i=total_builds; i>=0; --i ))
	do
		sha256_test="$(< ${paper_builds_ext} jq -r ".builds[$i].downloads.application.sha256")"
		cur_build_test="$(< ${paper_builds_ext} jq -r ".builds[$i].build")"
		if [ "${sha256}" = "${sha256_test}" ]
		then
			echo "Current installed Paper ${paper_ver} build is ${cur_build_test}"
			exit 0
		else
			continue
		fi
	done

	error_msg "could not determine build number\nPaper version likely differs from specified."
}

list_versions() {
	curl --fail -sX GET "${paper_api}/projects/paper/" | jq -r '.versions[]'
	if [ ! "${PIPESTATUS[0]}" -eq 0 ]
	then
		error_msg "curl: API error"
	else
		exit 0
	fi
}

list_builds() {
	curl --fail -sX GET "${paper_api}/projects/paper/versions/${paper_ver}/builds/" | jq -r . > "${paper_builds_ext}"
	if [ ! "${PIPESTATUS[0]}" -eq 0 ]
	then
		if [ ! -s "${paper_builds}" ]
		then
			rm -f "${paper_builds}"
		fi
		error_msg "curl: API error"
	fi
	
	local build

	echo -e "Paper ${paper_ver} (5 most recent builds)\n---------------"
	for (( i=-1; i>=-5; --i ))
	do
		build="$(< "${paper_builds_ext}" jq -r ".builds[$i].build")"
		commit_hash="$(< "${paper_builds_ext}" jq -r ".builds[$i].changes[].commit")"
		build_summary="$(< "${paper_builds_ext}" jq -r ".builds[$i].changes[].summary")"

		echo -e "Build ${build}\n  Commit: ${commit_hash}\n  Summary: ${build_summary}\n"
	done

	exit 0
}

usage() {
	cat <<-EOF
	Usage: ${prog_name} [OPTIONS...]
	${formal_name} uses the PaperMC API to obtain build information
	and download requested version and build.
	
	Required files are stored in same directory as script.
	Options required by another must precede.

	Examples:
	  ./${prog_name}		no options downloads newest version and newest build

	  ./${prog_name} -u 1.12.2		omitted build number defaults to newest

	  ./${prog_name} -u 1.16.5 -b 793 -n "paper-793.jar" -o "~/paper" -F

	  -h		displays this help
	  -u		set the Paper version
	  -b		set the Paper build; requires -u (optional)
	  -g		get build of current Paper jar; requires -u. -o and -n is optional
	  -n		set name for Paper jar; defaults to "paper.jar"
	  -o		set output location for download; defaults to current directory
	  -l		list Paper versions
	  -L		list last five Paper builds; requires -u
	  -f		overwrite existing Paper jar
	  -F		force download new Paper version and build jsons from API
	  -v		display script version

EOF
exit 0
}

while getopts ":vhu:b:gn:o:lLfF" opt
do
	case ${opt} in
		v)
			echo "${formal_name} version ${script_ver}"
			exit 0
			;;
		h)
			usage
			;;
		u)
			paper_ver="${OPTARG}"
			u_flag=true
			;;
		l)
			list_versions
			;;
		L)
			if ! $u_flag; then error_msg "$(error_option "L" "-u")"; fi
			list_builds
			;;
		b)
			if ! $u_flag; then error_msg "$(error_option "b" "-u")"; fi
			paper_build="${OPTARG}"
			b_flag=true
			;;
		n)
		 	paper_jar="${OPTARG}"
			if [ "${paper_jar##*.}" != "jar" ]
			then
				paper_jar="${paper_jar}.jar"
			fi
			;;
		o)
			paper_path=$(realpath -s -m "${OPTARG/#\~/$HOME}")
			;;
		g)
			if ! $u_flag; then error_msg "$(error_option "g" "-u")"; fi
			g_flag=true
			cur_build
			;;
		f)
			if $g_flag; then error_msg "option -- 'g' is exclusive"; fi
			if ! $u_flag; then no_ver_set=true; fi
			f_flag=true
			;;
		F)
			if $g_flag; then error_msg "option -- 'g' is exclusive"; fi
			force_new_json=true
			;;
		\?)
			error_msg "invalid option -- '${OPTARG}'\nUse '${prog_name} -h' to see help."
			;;
		:)
			error_msg "option -- '${OPTARG}' requires argument"
			;;
	esac
done
shift $((OPTIND - 1))

if [ ${OPTIND} -eq 1 ]
then
	no_ver_set=true
fi

check_net
check_reqs
update
