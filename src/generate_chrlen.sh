
usage() {
    echo "Usage: $0 -r <reference.fa> -t <target_file> -o <output_directory>"
    exit 1
}

# 解析参数
while getopts "r:t:o:" opt; do
    case $opt in
        r) ref="$OPTARG" ;;
        t) target="$OPTARG" ;;
        o) out_dir="$OPTARG" ;;
        *) usage ;;
    esac
done

# 检查必须参数
if [[ -z "$ref" || -z "$target" || -z "$out_dir" ]]; then
    usage
fi

# 检查参考文件和目标文件是否存在
if [[ ! -f "$ref" ]]; then
    echo "错误: 参考文件 $ref 不存在."
    exit 1
fi

if [[ ! -f "$target" ]]; then
    echo "错误: 目标文件 $target 不存在."
    exit 1
fi

# 创建输出目录
mkdir -p "$out_dir"

# 检查 .fai 文件是否存在，如不存在则生成
if [[ ! -f "${ref}.fai" ]]; then
    samtools faidx "$ref"
    if [[ $? -ne 0 ]]; then
        echo "错误: samtools faidx 生成索引失败."
        exit 1
    fi
fi

# 定义输出文件路径
chrlen_file="${out_dir}/chrlen.bed"

rm -f "$chrlen_file"
touch "$chrlen_file"

# 从目标文件中提取唯一的染色体名称（假设在第一列）
chromosomes=($(awk '{print $1}' "$target" | sort | uniq))
count=0

for chr in "${chromosomes[@]}"; do
    count=$((count + 1))
    # 从参考文件的 .fai 文件中获取染色体长度（第二列）
    length=$(awk -v chr="$chr" '$1==chr {print $2}' "${ref}.fai")
    echo -e "${count}\t${chr}\t${length}" >> "$chrlen_file"
    samtools faidx ${ref} "${chr}" > ${out_dir}/${chr}.fasta
done
