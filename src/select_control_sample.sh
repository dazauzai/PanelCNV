#!/bin/bash
# select_control.sh
# 用途：从输入文件夹中选择一个中间大小的 BAM 文件，并输出该文件的绝对路径（仅输出绝对路径）
# 用法: ./select_control.sh <input_folder>

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input_folder>" >&2
    exit 1
fi

input_folder="$1"

# 查找输入文件夹中所有后缀为 .bam 的文件，并按大小排序（降序排序）
# 注意：此处假设文件名中不包含空格，否则可能需要更严格的处理
files=($(find "$input_folder" -type f -name "*.bam" -exec ls -lS {} + | awk '{print $9}'))
file_count=${#files[@]}

if (( file_count == 0 )); then
    echo "No BAM files found in $input_folder" >&2
    exit 1
fi

# 计算中间索引：如果文件数为偶数则选择靠左的中间文件，奇数则选择正中间
if (( file_count % 2 == 0 )); then
    mid_index=$(( file_count / 2 - 1 ))
else
    mid_index=$(( file_count / 2 ))
fi

selected_file="${files[$mid_index]}"

# 输出该文件的绝对路径，仅输出绝对路径
readlink -f "$selected_file"
