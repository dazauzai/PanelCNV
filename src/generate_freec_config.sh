#!/bin/bash
# generate_config.sh
# 用途: 生成 FreeC 配置文件
# 用法:
#   ./generate_config.sh --tumor_bam <tumor_bam> --gender <gender> --ref_path <ref_path> \\
#                        --chrlen <chrlen> --dbSNP <dbSNP> --output_dir <output_dir> --maxThreads <maxThreads> \\
#                        --ploidy <ploidy> --control_bam <control_bam> --readCountThreshold <readCountThreshold> \\
#                        --breakPointThreshold <breakPointThreshold> --target <target>

script_dir="$(dirname "$(readlink -f "$0")")"

# 默认参数
maxThreads=8
ploidy="2,3,4"
minCNAlength=3
readCountThreshold=100
breakPointThreshold=0.8

usage() {
    echo "Usage: $0 --tumor_bam <tumor_bam> --gender <gender> --ref_path <ref_path> \\"
    echo "          --chrlen <chrlen> --dbSNP <dbSNP> --output_dir <output_dir> --maxThreads <maxThreads> \\"
    echo "          --ploidy <ploidy> --control_bam <control_bam> --readCountThreshold <readCountThreshold> \\"
    echo "          --breakPointThreshold <breakPointThreshold> --target <target>"
    exit 1
}

# 如果没有参数则显示帮助信息
if [ $# -eq 0 ]; then
    usage
fi

# 使用 getopt 解析长参数
TEMP=$(getopt -o '' \
    --long tumor_bam:,chr_files:,gender:,ref_path:,chrlen:,dbSNP:,output_dir:,maxThreads:,ploidy:,control_bam:,readCountThreshold:,breakPointThreshold:,target: \
    -n "$0" -- "$@")

if [ $? != 0 ]; then
    usage
fi

eval set -- "$TEMP"

# 解析参数
while true; do
    case "$1" in
        --tumor_bam) tumor_bam="$2"; shift 2 ;;
        --chr_files) chr_files="$2"; shift 2 ;;
        --gender) gender="$2"; shift 2 ;;
        --ref_path) ref_path="$2"; shift 2 ;;
        --chrlen) chrlen="$2"; shift 2 ;;
        --dbSNP) dbSNP="$2"; shift 2 ;;
        --output_dir) output_dir="$2"; shift 2 ;;
        --maxThreads) maxThreads="$2"; shift 2 ;;
        --ploidy) ploidy="$2"; shift 2 ;;
        --control_bam) control_bam="$2"; shift 2 ;;
        --readCountThreshold) readCountThreshold="$2"; shift 2 ;;
        --breakPointThreshold) breakPointThreshold="$2"; shift 2 ;;
        --target) target="$2"; shift 2 ;;
        --) shift; break ;;
        *) break ;;
    esac
done

# 确保输出目录正确格式化（去掉末尾的 `/`）
output_dir="${output_dir%/}"

# 调试输出，确保变量正确
echo "tumor_bam: $tumor_bam"
echo "chr_files: $chr_files"
echo "gender: $gender"
echo "ref_path: $ref_path"
echo "chrlen: $chrlen"
echo "dbSNP: $dbSNP"
echo "output_dir: $output_dir"
echo "maxThreads: $maxThreads"
echo "ploidy: $ploidy"
echo "control_bam: $control_bam"
echo "readCountThreshold: $readCountThreshold"
echo "breakPointThreshold: $breakPointThreshold"
echo "target: $target"

# 判断是否有 control_bam
if [[ -z "$control_bam" ]]; then
    prefix=$(basename "${tumor_bam}" ".bam")
    config_file="${output_dir}/${prefix}.config"
    mkdir -p "${output_dir}/control_freec/without_normal/${prefix}"
    mkdir -p "${output_dir}/control_freec/without_normal/config"

    cat > "${config_file}" <<EOF
[general]

chrLenFile = ${chrlen}
BedGraphOutput = TRUE
degree = 1
forceGCcontentNormalization = 1
intercept = 1
minCNAlength = 3
maxThreads = ${maxThreads}
noisyData = TRUE
outputDir = .
ploidy = ${ploidy}
printNA = FALSE
readCountThreshold = ${readCountThreshold}
sex = ${gender}
window = 0
breakPointThreshold = ${breakPointThreshold}
chrFiles = ${chr_files}

[sample]

mateFile = ${tumor_bam}
inputFormat = BAM
mateOrientation = FR

[BAF]

makePileup = ${dbSNP}
SNPfile = ${dbSNP}
fastaFile = ${ref_path}

[target]

captureRegions = ${target}
EOF

else
    control_path=$(bash "${script_dir}/select_control.sh" "${control_bam}")
    prefix=$(basename "${tumor_bam}" ".bam")
    mkdir -p "${output_dir}/control_freec/with_normal/config"
    mkdir -p "${output_dir}/control_freec/with_normal/${prefix}"
    config_file="${output_dir}/${prefix}.config"

    cat > "${config_file}" <<EOF
[general]

chrLenFile = ${chrlen}
BedGraphOutput = TRUE
degree = 1
forceGCcontentNormalization = 1
intercept = 1
minCNAlength = 3
maxThreads = ${maxThreads}
noisyData = TRUE
outputDir = .
ploidy = ${ploidy}
printNA = FALSE
readCountThreshold = ${readCountThreshold}
sex = ${gender}
window = 0
breakPointThreshold = ${breakPointThreshold}
chrFiles = ${chr_files}

[sample]

mateFile = ${tumor_bam}
inputFormat = BAM
mateOrientation = FR

[control]

mateFile = ${control_path}
inputFormat = BAM
mateOrientation = FR

[BAF]

makePileup = ${dbSNP}
SNPfile = ${dbSNP}
fastaFile = ${ref_path}

[target]

captureRegions = ${target}
EOF
fi

echo "Config file generated: ${config_file}"
