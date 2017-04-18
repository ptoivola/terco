#!/bin/bash
#Get the latest script from https://github.com/ptoivola/terco
#set -x #tracing
set -e #exit on error
function setup {
asking_intensity=1 #Supported: 1,2. 1 automated mode and 2 asks for user consent more.
work_dir=./ #Directory where the script finds the command list and writes the new configuration based on those commands.
original_config_dir=~/.config/terminator/ #Location of the original configuration. Script writes here too.
original_config=${original_config_dir}config #Original Terminator configuration file. This will be destroyed.
config_file=${work_dir}terminator_config #Temporary configuration file that will replace the original configuration
cmd_list=${work_dir}command_list_example.txt #List of groups and commands you wish to run.
profile_name=tomato #Not meaningful at the moment.
default_grid_size=32 #supported: 4,8,16,32. Maximum amount of terminals per window.
line_number=1
echo -e '\033[0;31m'WARNING!'\033[0m'
echo -e '\033[0;31m'We will write to '\033[0;32m'${work_dir}'\033[0;31m'.'\033[0m'
echo -e '\033[0;31m'This will destroy your existing terminator configuration in'\033[0;32m' ${original_config}'\033[0;31m'.'\033[0m'
echo -e '\033[0;31m'Terminate now with '\033[0;32m'Ctrl + c'\033[0;31m'.'\033[0m'
read nullers
ask_user_consent "We will use ${cmd_list}"
if [ ! -d "${work_dir}" ]; then
    ask_user_consent "mkdir -p $work_dir"
    mkdir -p $work_dir
else
    ask_user_consent "directory $work_dir exists, using it..."
fi
ask_user_consent "We will replace ${original_config}." "We will write to ${work_dir}." "We will start possibly multiple terminator windows."

if [ -e "${config_file}" ]; then
    ask_user_consent "mkdir -p $work_dir"
    mv ${config_file} ${config_file}_previous
fi
}

function ask_user_consent {
    auc_answer=0
        if [ ! -z "${1}" ]; then echo -e $1; fi
        if [ ! -z "${2}" ]; then echo -e $2; fi
        if [ ! -z "${3}" ]; then echo -e $3; fi
    if [[ ${asking_intensity} -le 1  ]]; then
        echo "Terminate script with Ctrl + c "
        sleep 1
    fi
    if [[ ${asking_intensity} -eq 2  ]]; then
        while   [[ ${auc_answer} != @(Y|n) ]]; do
            echo "Is this Ok? (Y/n)"
            read auc_answer
        done
        if [[ ${auc_answer} = Y ]]; then
            echo "Thants!"
            else
            echo "User ended the script"
            exit 0
        fi
    fi
}

function user_set_max_grid_size {
max_grid_size_set=0
if [[ ${asking_intensity} -le 1  ]]; then
    ask_user_consent "Maximum grid size will be ${default_grid_size}"
    max_grid_size=${default_grid_size}
fi
if [ ${asking_intensity} -eq 2  ]; then
    while   [[ ${max_grid_size} != @(4|8|16|32) ]]; do
        echo "Choose maximux grid size: 4,8,16,32"
        read max_grid_size
        max_grid_size_set=1
    done
fi
}

function calc_window_count {
window_count=$((${cmd_count}/${max_grid_size}))
if [ $((${cmd_count}%${max_grid_size})) -gt 0 ]; then
    window_count=$((${window_count}+1))
fi
}

function cmd_list_setup {
cmd_count=$(cat ${cmd_list}|wc -l)
if [ ${cmd_count} -le 1 ]; then
    echo too few commands available
    exit 0
fi
}

function choo_grid_size {
if   [ ${cmd_count} -le 4  ]
    then grid_size=4
elif [ ${cmd_count} -le 8  ]
    then grid_size=8
elif [ ${cmd_count} -le 16  ]
    then grid_size=16
elif [ ${cmd_count} -le 32 ]
    then grid_size=32
else
    echo "Not able to fit all commands to this grid"
    grid_size=${max_grid_size}
fi
if [ ${grid_size} -gt ${max_grid_size} ]; then
    grid_size=${max_grid_size}
fi
}

function config_file_setup {
cat >> ${config_file}<<EOF
[global_config]
exit_action = restart
focus = mouse
font = Monospace 6
handle_size = 1
scroll_tabbar = True
scrollback_infinite = True
suppress_multiple_term_dialog = True
use_system_font = False
[keybindings]
[profiles]
[[default]]
[layouts]
EOF
split_number=0
terminal_number=0
window_number=0
}

function config_file_add_window {
logger_newline layout_${window_number}
cat >> ${config_file}<<EOF
[[layout_${window_number}]]
[[[window_${window_number}]]]
position = 960:0
type = Window
order = 0
parent = ""
size = 960, 1080
EOF
}

function config_file_add_grid {
max_split_name=$((${grid_size}-1))
while [[ ${loop_counter_grid} -lt ${max_split_name} ]]; do
    split_number=$((${split_number}+1))
    split_name=split_${split_number}
    if [ ${split_number} -ge 2 -a ${split_number} -le  3 ] || [ ${split_number} -ge 8 -a ${split_number} -le 31 ]; then
        split_type=VPaned
    else
        split_type=HPaned
    fi
    if [ $((${split_number}%2)) -eq 1 ]; then
        split_order=0
    else
        split_order=1
    fi
    if   [ ${split_number} -eq 1 ];then
        split_parent=window_${window_number}
    elif [ $((${split_number}%2)) -eq 1 ]; then
        split_parent=split_$((((${split_number}-1))/2))
    else
        split_parent=split_$((${split_number}/2))
    fi
write_grid_to_file
loop_counter_grid=${loop_counter_grid}+1
done
}

function write_grid_to_file {
cat >> ${config_file}<<EOF
[[[${split_name}]]]
type = ${split_type}
order = ${split_order}
parent = ${split_parent}
EOF
logger ${split_name}
}

function config_file_add_terminals {
while [[ $loop_counter_terminals -lt $cmd_count && $loop_counter_terminals -lt $grid_size ]]; do
    terminal_number=$((${terminal_number}+1))
    terminal_name=terminal_${terminal_number}
    terminal_profile=${profile_name}
    terminal_type=Terminal
    if [ $((${terminal_number}%2)) -eq 1 ]; then
        terminal_order=0
    else
        terminal_order=1
    fi
    if   [ ${grid_size} -eq  4 ]; then
        if   [ ${terminal_number} -ge  1 -a ${terminal_number} -le  2 ]; then terminal_parent=split_3
        elif [ ${terminal_number} -ge  3 -a ${terminal_number} -le  4 ]; then terminal_parent=split_2
    fi
    elif [ ${grid_size} -eq  8 ]; then
        if   [ ${terminal_number} -ge  1 -a ${terminal_number} -le  2 ]; then terminal_parent=split_7
        elif [ ${terminal_number} -ge  3 -a ${terminal_number} -le  4 ]; then terminal_parent=split_6
        elif [ ${terminal_number} -ge  5 -a ${terminal_number} -le  6 ]; then terminal_parent=split_5
        elif [ ${terminal_number} -ge  7 -a ${terminal_number} -le  8 ]; then terminal_parent=split_4
        fi
    elif [ ${grid_size} -eq 16 ]; then
        if   [ ${terminal_number} -ge  1 -a ${terminal_number} -le  2 ]; then terminal_parent=split_15
        elif [ ${terminal_number} -ge  3 -a ${terminal_number} -le  4 ]; then terminal_parent=split_13
        elif [ ${terminal_number} -ge  5 -a ${terminal_number} -le  6 ]; then terminal_parent=split_14
        elif [ ${terminal_number} -ge  7 -a ${terminal_number} -le  8 ]; then terminal_parent=split_12
        elif [ ${terminal_number} -ge  9 -a ${terminal_number} -le 10 ]; then terminal_parent=split_11
        elif [ ${terminal_number} -ge 11 -a ${terminal_number} -le 12 ]; then terminal_parent=split_9
        elif [ ${terminal_number} -ge 13 -a ${terminal_number} -le 14 ]; then terminal_parent=split_10
        elif [ ${terminal_number} -ge 15 -a ${terminal_number} -le 16 ]; then terminal_parent=split_8
        fi
    elif [ ${grid_size} -eq 32 ]; then
        if   [ ${terminal_number} -ge  1 -a ${terminal_number} -le  2 ]; then terminal_parent=split_31
        elif [ ${terminal_number} -ge  3 -a ${terminal_number} -le  4 ]; then terminal_parent=split_30
        elif [ ${terminal_number} -ge  5 -a ${terminal_number} -le  6 ]; then terminal_parent=split_27
        elif [ ${terminal_number} -ge  7 -a ${terminal_number} -le  8 ]; then terminal_parent=split_26
        elif [ ${terminal_number} -ge  9 -a ${terminal_number} -le 10 ]; then terminal_parent=split_29
        elif [ ${terminal_number} -ge 11 -a ${terminal_number} -le 12 ]; then terminal_parent=split_28
        elif [ ${terminal_number} -ge 13 -a ${terminal_number} -le 14 ]; then terminal_parent=split_25
        elif [ ${terminal_number} -ge 15 -a ${terminal_number} -le 16 ]; then terminal_parent=split_24
        elif [ ${terminal_number} -ge 17 -a ${terminal_number} -le 18 ]; then terminal_parent=split_23
        elif [ ${terminal_number} -ge 19 -a ${terminal_number} -le 20 ]; then terminal_parent=split_22
        elif [ ${terminal_number} -ge 21 -a ${terminal_number} -le 22 ]; then terminal_parent=split_19
        elif [ ${terminal_number} -ge 23 -a ${terminal_number} -le 24 ]; then terminal_parent=split_18
        elif [ ${terminal_number} -ge 25 -a ${terminal_number} -le 26 ]; then terminal_parent=split_21
        elif [ ${terminal_number} -ge 27 -a ${terminal_number} -le 28 ]; then terminal_parent=split_20
        elif [ ${terminal_number} -ge 29 -a ${terminal_number} -le 30 ]; then terminal_parent=split_17
        elif [ ${terminal_number} -ge 31 -a ${terminal_number} -le 32 ]; then terminal_parent=split_16
        fi
    fi
    terminal_command=$(sed -n ${line_number}p ${cmd_list} |sed 's/[^ ]* //')
    terminal_group=$(sed -n ${line_number}p ${cmd_list} |cut -d ' ' -f1)
    write_terminal_to_file
    loop_counter_terminals=$((${loop_counter_terminals} + 1))
    line_number=$((${line_number} + 1))
done
}

function write_terminal_to_file {
cat >> ${config_file}<<EOF
[[[${terminal_name}]]]
profile = ${terminal_profile}
type = ${terminal_type}
order = ${terminal_order}
parent = ${terminal_parent}
command = ${terminal_command}
group = ${terminal_group}
EOF
logger ${terminal_command}
}

function destroy_terminator_config {
ask_user_consent "mv ${original_config}  ${original_config}_old"
mv ${original_config}  ${original_config}_old #$(date +%Y%m%d%H%M%S)
}

function start_terminator_with_new_config {
ask_user_consent "mkdir -p ${original_config_dir} && cp ${config_file} ${original_config}"
mkdir -p ${original_config_dir} && cp ${config_file} ${original_config}
while [ ! ${window_number} -le 0 ]; do
    window_number=$((${window_number} - 1))
    logger_newline "starting terminator with layout_${window_number}"
    terminator -l layout_${window_number} &
    sleep 1
done
}

function logger {
echo -ne '\033[0;31m'Action:'\033[0m' '\033[0;32m'${1}'\033[0m' \\r
sleep 0.01
}

function logger_newline {
echo -e '\033[0;31m'Action:'\033[0m' '\033[0;32m'${1}'\033[0m'
sleep 0.01
}

setup
user_set_max_grid_size
cmd_list_setup
calc_window_count
config_file_setup
while [ ! ${cmd_count} -le 0 ]; do
    choo_grid_size
    config_file_add_window
    config_file_add_grid
    config_file_add_terminals
    cmd_count=$((${cmd_count}-${grid_size}))
    window_number=$((${window_number} + 1))
    loop_counter_terminals=0
    loop_counter_grid=0
    terminal_number=0
    split_number=0
done
destroy_terminator_config
start_terminator_with_new_config
exit 0
