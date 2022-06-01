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

if [ "$(id -u)" -eq 0 ]
then
	echo "do not run this script as root"
	exit 1
fi

paper_jar="paper.jar"
paper_api="https://papermc.io/api/v2"
paper_builds="paper_builds.json"
paper_versions="paper_versions.json"

prog_name="$(basename "${0}")"
formal_name="YAPManTool Updater"

script_ver="0.1"


check_reqs() {
	req_progs=(curl wget jq)
	for prog in "${req_progs[@]}"
	do
		if ! command -v "${prog}" > /dev/null 2>&1
		then
			echo "${prog_name}: missing program '${prog}'" >&2
			echo "This script requires the following programs: ${req_progs[*]}" >&2
			exit 1
		fi
	done
}

parse() {
	if $no_ver_set && [ ! -f "${paper_builds}" ]
	then
		paper_ver="$(< ${paper_versions} jq -r '.versions[-1]')"
		curl -sX GET "${paper_api}/projects/paper/versions/${paper_ver}/" | jq . > paper_builds.json
	fi

	if $no_ver_set && [ -f "${paper_builds}" ]
	then
		paper_ver="$(< ${paper_versions} jq -r '.versions[-1]')"
		latest_build="$(< paper_builds.json jq -r '.builds[-1]')"
		download_url="${paper_api}/projects/paper/versions/${paper_ver}/builds/${latest_build}/downloads/paper-${paper_ver}-${latest_build}.jar"
		curl -o "${paper_path}/${paper_jar}" -L "${download_url}"
	fi

}

update() {
	if [ -f "${paper_versions}" ]
	then
		parse
	else
		curl -sX GET "${paper_api}/projects/paper/" | jq . > paper_versions.json
		parse
	fi
}

usage() {
	cat <<-EOF
	Usage: ${prog_name} [OPTIONS...]
	${prog_name} downloads or updates the current Paper server jar with a
	specified build or the newest build if unspecified.

	Examples:
	  examples go here.

	  -h		displays this help
	  -u		set the Paper version
	  -b		set the Paper build; needs -u (optional)
	  -g		get build of current Paper jar; assumes build json is present
	  -n		set name for Paper jar
	  -o		set output location for download
	  -v		display script version

EOF
exit 0
}

while getopts ":vhu:b:gn:o:" opt
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
			;;
		b)
			if [ -z "${paper_ver+x}" ]
			then
				echo "${prog_name}: option -- 'b' requires '-u'" >&2
				exit 1
			fi
			paper_build="${OPTARG}"
			;;
		g)
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
			;;
		\?)
			echo "${prog_name}: invalid option -- '${OPTARG}'" >&2
			echo "Use '${prog_name} -h' to see help." >&2
			exit 1
			;;
		:)
			echo "${prog_name}: option -- '${OPTARG}' requires argument" >&2
			exit 1
			;;
	esac
	unset no_arg
	no_arg=true
done
shift $((OPTIND - 1))

if $no_arg
then
	unset no_arg
	paper_path=.
	no_ver_set=true
	update
fi

# this won't work as is. fix
if [ -z "${paper_build+x}" ]
then
	paper_build="${latest_build}"
	update
fi