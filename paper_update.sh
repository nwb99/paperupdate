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

if [ "$(id -u)" -eq 0 ]
then
	echo "do not run this script as root"
	exit 1
fi

paper_jar="paper.jar"
paper_api="https://papermc.io/api/v2"
paper_builds="paper_builds.json"
paper_versions="paper_versions.json"
download_url="${paper_api}/projects/paper/versions/${paper_ver}/builds/${build}/downloads/paper-${paper_ver}-${build}.jar"

prog_name="$(basename "${0}")"
formal_name="YAPManTool Updater"

script_ver="0.1"


u_flag=false
o_flag=false
b_flag=false
g_flag=false


error_msg() {
		echo -e "${prog_name}: ${1}" >&2
		exit 1
}

error_option() {
	echo -e "option -- '${1}' requires '${2}'"
}

check_reqs() {
	req_progs=(curl jq)
	for prog in "${req_progs[@]}"
	do
		if ! command -v "${prog}" > /dev/null 2>&1
		then
			error_msg "missing program '${prog}'\nThis script requires the following programs: ${req_progs[*]}"
		fi
	done
}

shasum_f() {
	sha256="$(sha256sum ${paper_jar} | cut -d ' ' -f1)"
	expected_sha256="$(curl -sX GET "${paper_api}/projects/paper/versions/${paper_ver}/builds/${build}" | jq -r '.downloads.application.sha256')"

	if [ "${sha256}" != "${expected_sha256}" ]
	then
		error_msg "SHA256 for downloaded Paper jar does not match what is expected."
	else
		echo "SHA256 matches. Done!"
		exit 0
	fi
}

update() {
	if [ ! -f "${paper_versions}" ] || $force_new_json
	then
		curl -sX GET "${paper_api}/projects/paper/" | jq . > "${paper_versions}"
	fi

	if ( $no_ver_set && [ ! -f "${paper_builds}" ] ) || ( $no_ver_set && $force_new_json )
	then
		paper_ver="$(< ${paper_versions} jq -r '.versions[-1]')"
		curl -sX GET "${paper_api}/projects/paper/versions/${paper_ver}/" | jq . > "${paper_builds}"
	fi

	if $no_ver_set
	then
		paper_ver="$(< ${paper_versions} jq -r '.versions[-1]')"
	fi

	if ! $b_flag
	then
		curl -sX GET "${paper_api}/projects/paper/versions/${paper_ver}/" | jq . > paper_builds.json
		build="$(< paper_builds.json jq -r '.builds[-1]')"
	else
	 	build="${paper_build}"
	fi

	download_url="${paper_api}/projects/paper/versions/${paper_ver}/builds/${build}/downloads/paper-${paper_ver}-${build}.jar"
	echo "Downloading Paper ${paper_ver} build ${build} to \"${paper_path}/${paper_jar}\""
	curl -o "${paper_path}/${paper_jar}" -L "${download_url}"
	sync
	shasum_f
}

curbuild() {
	if [ ! -f "${paper_builds}" ]
	then
		error_msg "${paper_builds}: no such file"
	fi

}

usage() {
	cat <<-EOF
	Usage: ${prog_name} [OPTIONS...]
	${formal_name} downloads or updates the current Paper server jar with a
	specified build or the newest build if unspecified.
	
	Required files are stored in same directory as script.

	Examples:
	  examples go here.

	  -h		displays this help
	  -u		set the Paper version
	  -b		set the Paper build; requires -u (optional)
	  -g		get build of current Paper jar; assumes build json is present
	  -n		set name for Paper jar
	  -o		set output location for download; defaults to current directory
	  -l		list Paper versions
	  -L		list last five Paper builds; requires -u
	  -F		force download new Paper version and build json
	  -v		display script version

EOF
exit 0
}

while getopts ":vhu:b:gn:o:lLF" opt
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
			# should eval be used here?
			if ! $u_flag; then error_msg "$(error_option "L" "-u")"; fi
			list_builds
			;;
		b)
			if ! $u_flag; then error_msg "$(error_option "b" "-u")"; fi
			paper_build="${OPTARG}"
			b_flag=true
			;;
		g)
			if ! $u_flag; then error_msg "$(error_option "g" "-u")"; fi
			paper_build="${OPTARG}"
			g_flag=true
			cur_build
			;;
		n)
		 	paper_jar="${OPTARG}"
			if [ "${paper_jar##*.}" != "jar" ]
			then
				paper_jar="${paper_jar}.jar"
			fi
			;;
		o)
			paper_path="${OPTARG}"
			o_flag=true
			;;
		F)
			if $g_flag
			then
				error_msg "option -- 'g' is exclusive"
			fi
			force_new_json=true
			;;
		\?)
			error_msg "invalid option -- '${OPTARG}'\nUse '${prog_name} -h' to see help."
			;;
		:)
			error_msg "option -- '${OPTARG}' requires argument"
			;;
	esac
	unset no_arg
	no_arg=true
done
shift $((OPTIND - 1))

if ! $o_flag
then
	paper_path=.
fi

if $no_arg
then
	unset no_arg
	no_ver_set=true
fi

update
