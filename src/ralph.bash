#! /usr/bin/env bash

set -euo pipefail

FORCE=false
VERBOSE=false
ITERATIONS=10
INIT=false
TASK_FILE=""
RALPH_DIR="$(pwd)/.ralph"

usage() {
	cat <<- EOF
		Usage: ralph [options] [init|<filepath>]
		    -h, --help                   Show this help message and exit
		    -f, --force                  Force the operation, even if it is already completed
		    -v, --verbose                Enable verbose output
		    -n <num>, --iterations <num> Number of iterations to perform (default: 10)
	EOF
}

verbose() {
	if ${VERBOSE}; then
		echo "$@"
	fi
}

parse-args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				usage
				exit 0
				;;
			-f|--force)
				FORCE=true
				shift
				;;
			-v|--verbose)
				VERBOSE=true
				shift
				;;
			-n|--iterations)
				if [[ -n "$2" && "$2" != -* ]]; then
					ITERATIONS="$2"
					shift 2
				else
					echo "Error: --iterations requires a value"
					usage
					exit 1
				;;
			*)
				break
				;;
		esac
	done

	if [[ $# -gt 0 ]]; then
		if [[ "$1" == "init" ]]; then
			INIT=true
		else
			TASK_FILE="$1"
		fi
	fi
}

init() {
	echo "Initializing Ralph..."
	mkdir -p "$(pwd)/.ralph"
	# Check if .gitignore exists and add .ralph to it
	if [[ -f "$(pwd)/.gitignore" ]]; then
		if ! grep -q "^.ralph$" "$(pwd)/.gitignore"; then
			echo ".ralph" >> "$(pwd)/.gitignore"
			echo "Added .ralph to .gitignore"
		fi
	fi
}

main() {
	parse-args "$@"

	if ${INIT}; then
		init
		return
	fi

	mkdir -p "${RALPH_DIR}"
	if [[ -z "${TASK_FILE}" ]]; then
		# Check if stdin has input
		if [ -t 0 ]; then
			echo "No task file provided and no input from stdin. Exiting."
			exit 1
		else
			TASK_FILE="/dev/stdin"
		fi
	fi
	
	verbose "Task file: ${TASK_FILE}"
	verbose "Iterations: ${ITERATIONS}"
	verbose "Force? ${FORCE}"

	if [[ -f "${RALPH_DIR}/.done" ]]; then
		if ${FORCE}; then
			verbose "Force flag is set. Removing .done file to allow re-execution."
			rm -f "${RALPH_DIR}/.done"
		else
			echo "Task already completed. Use --force to re-run."
			exit 0
		fi
	fi

	# Do iterations
	for i in $(seq 1 "${ITERATIONS}"); do
		verbose "Iteration ${i}/${ITERATIONS}"
		
	done
}

main "$@"
