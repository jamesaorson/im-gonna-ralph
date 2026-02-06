#! /usr/bin/env bash

set -euo pipefail

STDIN=/dev/stdin

FORCE=false
VERBOSE=false
ITERATIONS=10
INIT=false
TASK_FILE=""
RALPH_DIR="$(pwd)/.ralph"
DEFAULT_TASK_FILE="${RALPH_DIR}/tasks"

usage() {
	cat <<- EOF
		Usage: ralph [options] [subcommand]

		Options:
		    -h, --help                   Show this help message and exit
		    -v, --verbose                Enable verbose output
		    -f <file>, --file <file>     Specify a task file (default: read from stdin, or .ralph/$(basename "${DEFAULT_TASK_FILE}"), or the lexicographically first .md/.txt file in $(basename "${RALPH_DIR}")
		    -n <num>, --iterations <num> Number of iterations to perform (default: 10)
		    --force                      Force the task to run even if it is marked as completed

		Subcommands:
		    init                          Initialize the Ralph environment in the current directory
	EOF
}

error() {
	echo "Error: $1" >&2
}

fatal() {
	error "$1"
	exit 1
}

fatal-with-usage() {
	error "$1"
	usage
	exit 1
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
			--force)
				FORCE=true
				shift
				;;
			-f|--file)
				if [[ $# -gt 1 && "$2" != -* ]]; then
					TASK_FILE="$2"
					shift 2
				else
					fatal-with-usage "$1 requires a value"
				fi
				;;
			-v|--verbose)
				VERBOSE=true
				shift
				;;
			-n|--iterations)
				if [[ $# -gt 1 ]]; then
					ITERATIONS="$2"
					if ! [[ "${ITERATIONS}" =~ ^[0-9]+$ ]]; then
						fatal-with-usage "$1 must be a positive integer"
					fi
					shift 2
				else
					fatal-with-usage "$1 requires a value"
				fi
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
			fatal-with-usage "Unknown subcommand: $1"
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
		if [ ! -t 0 ]; then
			TASK_FILE="${STDIN}"
		else
			# Select first file by name of DEFAULT_TASK_FILE, or any text extension
			if [[ -f "${DEFAULT_TASK_FILE}" ]]; then
				TASK_FILE="${DEFAULT_TASK_FILE}"
			else
				TASK_FILE=$(find "${RALPH_DIR}" -maxdepth 1 -type f \( -name "*.md" -o -name "*.txt" \) | sort | head -n 1)
				if [[ -z "${TASK_FILE}" ]]; then
					fatal-with-usage "No task file provided and no suitable files found in $(basename "${RALPH_DIR}"). Exiting."
				fi
			fi
		fi
	fi

	if [[ "${TASK_FILE}" != "${STDIN}" && ! -f "${TASK_FILE}" ]]; then
		fatal "Task file not found: ${TASK_FILE}"
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
		ralph-loop "${TASK_FILE}"
	done
}

ralph-loop() {
	verbose "Processing task file: $1"
	
}

main "$@"
