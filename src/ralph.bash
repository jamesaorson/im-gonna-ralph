#! /usr/bin/env bash

set -euo pipefail

STDIN=/dev/stdin

FORCE=false
VERBOSE=false
ITERATIONS=10
INIT=false
TASK_FILE=""
RALPH_DIR="$(pwd)/.ralph"
DONE_FILE="${RALPH_DIR}/.done"
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

	if [[ -f "${DONE_FILE}" ]]; then
		if ${FORCE}; then
			verbose "Force flag is set. Removing ${DONE_FILE} file to allow re-execution."
			rm -f "${DONE_FILE}"
		else
			echo "Task already completed. Use --force to re-run."
			exit 0
		fi
	fi

	local ITERATION_DIR
	ITERATION_DIR="${RALPH_DIR}/$(date +%Y%m%d_%H%M%S)"
	mkdir -p "${ITERATION_DIR}"

	if [[ -f "${RALPH_DIR}/.done" ]]; then
		echo "Task already completed. Use --force to re-run."
		exit 0
	fi

	# Do iterations
	for i in $(seq 1 "${ITERATIONS}"); do
		verbose "Iteration ${i}/${ITERATIONS}"
		ralph-loop "${i}" "${TASK_FILE}" "${ITERATION_DIR}"
	done
}

ralph-loop() {
	verbose "Processing task file $1 in dir $2"

	local ITERATION
	ITERATION="$1"
	shift
	local TASK_FILE
	TASK_FILE="$1"
	shift
	local ITERATION_DIR
	ITERATION_DIR="$1"
	shift

	# Adapted from https://gist.github.com/Tavernari/01d21584f8d4d8ccea8ceca305656ab3
	local HISTORY_CONTEXT=""
	
	if [ "${ITERATION}" -gt 0 ]; then
		echo "   (Reading memory from previous iterations...)"
		for (( i=0; i < ITERATION; i++ )); do
			local PREV_FILE
			PREV_FILE="${ITERATION_DIR}/iteration_$i.txt"
			if [ -f "$PREV_FILE" ]; then
				STEP_CONTENT=$(cat "$PREV_FILE")
				HISTORY_CONTEXT += $'\n'"--- HISTORY (Iteration #${i}) ---"$'\n'"${STEP_CONTENT}"$'\n'
			fi
		done
	fi

		FULL_PROMPT="
$(cat "$TASK_FILE")

====== SHORT-TERM MEMORY (What you already tried) ======
${HISTORY_CONTEXT}
========================================================

LOOP INSTRUCTIONS:
1. You are running in an autonomous loop.
2. Analyze the history above. If you tried something and it failed, try a different approach.
3. YOU are responsible for ensuring the code works. Run your own internal checks/tests if possible.
4. If the task is 100% COMPLETE and TESTED, create a '${DONE_FILE}' file.
5. If not finished, briefly describe your progress and what you expect should be done in the next iteration.
"

		OUTPUT=$(auggie --print --quiet "$FULL_PROMPT")

		local CURRENT_LOG_FILE
		CURRENT_LOG_FILE="${ITERATION_DIR}/iteration_${ITERATION}.txt"
		echo "${OUTPUT}" > "${CURRENT_LOG_FILE}"
		echo "Thought process saved: ${CURRENT_LOG_FILE}"

		if [[ -f "${DONE_FILE}" ]]; then
			echo "-----------------------------------"
			echo "Agent reported completion."
			echo "Full history available at: ${ITERATION_DIR}"
			touch "${DONE_FILE}"
			exit 0
		fi
		((ITERATION++))
		# Delay to avoid rate limits
		sleep 2
	done

	fatal "Reached maximum iterations ($MAX_ITERATIONS) without completion."
	exit 1
}

main "$@"
