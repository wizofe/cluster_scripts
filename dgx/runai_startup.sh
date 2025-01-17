#!/bin/bash

set -e # exit on error

#####################################################################################
# Default variables
#####################################################################################
run_dir=$(pwd)
cmd="sleep infinity"

#####################################################################################
# Usage
#####################################################################################
print_usage()
{
    echo "Script to be run at start of runai job."
    echo
    echo "Brief syntax:"
    echo "${0##*/} [OPTIONS(0)...] [ : [OPTIONS(N)...]] [-- <cmd>]"
    echo
    echo "Full syntax:"
    echo "${0##*/} [-h|--help] [-d|--dir <val>] [-- <cmd>]"
    echo
    echo "options without args:"
    echo "-h, --help                : Print this help."
    echo
    echo "options with args:"
    echo "-d, --dir <val>           : Directory to run from. Default: \`pwd\`."
    echo "-e, --env <name=val>      : Environmental variable, given as \"NAME=VAL\"."
    echo "                            Can be used multiple times."
    echo
    echo "NB: if \`-- <cmd>\` not given, \`sleep infinity\` is used."
}

#####################################################################################
# Parse input arguments
#####################################################################################
while [[ $# -gt 0 ]]; do
    key="$1"
    shift
    if [ "$key" == "--" ]; then
        if [ "$#" -gt 0 ]; then
            cmd="$*"
        fi
        break
    fi
    case $key in
        -h|--help)
            print_usage
            exit 0
        ;;
        -d|--dir)
            run_dir=$1
            shift
        ;;
        -e|--env)
            if [[ -z "${envs}" ]]; then envs=(); fi
            envs+=("$1")
            shift
        ;;
        *)
            echo -e "\n\nUnknown argument: $key\n\n"
            print_usage
            exit 1
        ;;
    esac
done

# Print vals
echo
echo "Path: ${run_dir}"
echo "Command: ${cmd}"
echo "SSH address: $(hostname -i)"
echo
echo "Environmental variables:"
for env in "${envs[@]}"; do
    echo -e "\t${env}"
done
echo

#####################################################################################
# Correct "~" (runai bug), source bashrc, add env vars, cd to run dir
#####################################################################################

export HOME
HOME=/nfs/home/$(whoami)
source "/nfs/home/$(whoami)/.bashrc"
source "/home/$(whoami)/.bashrc"
cp -r "/nfs/home/$(whoami)/.vscode-server" "/home/$(whoami)/.vscode-server"

# Add any environmental variables
for env in "${envs[@]}"; do
    export ${env}
    printf "export %s\n" "${env}" >> ~/.bashrc
done

cd "$run_dir"

#####################################################################################
# Start jupyter, sshd and vnc (if there)
#####################################################################################
nohup /usr/sbin/sshd -D -f "/home/$(whoami)/.ssh/sshd_config" -E "/home/$(whoami)/.ssh/sshd.log" &
nohup jupyter notebook --ip 0.0.0.0 --no-browser --notebook-dir=".." > "/home/$(whoami)/.jupyter_notebook.log" 2>&1 &
vncserver -SecurityTypes None 2>&1 || true

#####################################################################################
# Execute command
#####################################################################################
# the trap code is designed to send a stop (SIGTERM) signal to child processes,
# thus allowing python code to catch the signal and execute a callback
trap 'trap " " SIGTERM; kill 0; wait' SIGTERM

echo running "${cmd}"
${cmd} &
wait $!
