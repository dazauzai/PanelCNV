process PREPARE_REFERENCE {
    tag "PREP_REF"
    label 'high_mem'
    container 'dukegcb/bwa-samtools:latest'
    input:
    path ref_fasta
    path target_bed
    output:
    tuple path("*.bed"), path("ref"), emit: out
    script:
    """
    #!/bin/bash

    ${projectDir}/src/generate_chrlen.sh -r ${ref_fasta} -t ${target_bed} -o .
    mkdir -p ref
    mv ./*fasta ref/
    """
}


process generate_freec_config {
    tag "${sample_id}"
    cpus 1  // 配置文件生成不消耗计算资源
    label 'low_mem'
    input:
    tuple val(sample_id), path(tumor_bam), val(gender)
    tuple path(chrlen), path(chr_files)
    tuple path(dbSNP), path(target_bed), path(ref_fasta)
    val selected_control
    output:
    path("*.config"), emit: config

    script:
    """
    prefix=\$(basename ${tumor_bam} .bam)
    # 动态生成 control_bam 参数
    control_arg=""
    if [ "${selected_control}" != "no_control" ]; then
        control_arg="--control_bam=${selected_control}"
    fi

    # 检查必需文件是否存在
    if [ ! -f "${chrlen}" ]; then
        echo "ERROR: chrlen file ${chrlen} not found!" >&2
        exit 1
    fi
    if [ ! -f "${ref_fasta}" ]; then
        echo "ERROR: ref_path file ${ref_fasta} not found!" >&2
        exit 1
    fi
    if [ ! -d "${chr_files}" ]; then
        echo "ERROR: chr_files directory ${chr_files} not found!" >&2
        exit 1
    fi

    # 运行主命令
    ${projectDir}/src/generate_freec_config.sh \\
        "--tumor_bam=${tumor_bam}" \\
        "--gender=${gender}" \\
        "--chr_files=${chr_files}" \\
        "--dbSNP=${dbSNP}" \\
        "--target=${target_bed}" \\
        "--output_dir=." \\
        "--maxThreads=${params.freec.threads}" \\
        "--ploidy=${params.freec.ploidy}" \\
        "--readCountThreshold=${params.freec.readCountThreshold}" \\
        "--breakPointThreshold=${params.freec.breakPointThreshold}" \\
        "--chrlen=${chrlen}" \\
        "--ref_path=${ref_fasta}" \\
        \$control_arg


    """


}

process select_control {
    tag "SELECT_CONTROL"
    label 'low_mem'

    input:
    path normal_dir  // 输入正常样本的目录路径

    output:
    val selected_path, emit: control_path  // 声明为值输出，传递路径字符串

    script:
    """
    #!/bin/bash
    # 去除多余括号，错误处理建议添加
    selected_control=\$(bash ${projectDir}/select_control.sh "\${normal_dir}")

    # 验证路径有效性，可选步骤
    if [ -n "\$selected_control" ] && [ -e "\$selected_control" ]; then
        echo "\$selected_control"  // 输出有效路径
    else
        exit 1
    fi
    """
}


process RUN_FREEC {
    tag "FREEC_${sample}"
    label 'high_mem'
    container 'dazauzai/rc_image:latest'
    publishDir "${params.output_dir}/results", pattern: "*.CNVs", mode: 'copy'

    input:
    path config_file
    tuple val(sample_id), path(tumor_bam), val(gender)
    tuple path(chrlen), path(chr_files)
    tuple path(dbSNP), path(target_bed), path(ref_fasta)
    val selected_control
    output:
    path "./*", emit: out_control_freec

    script:
    """
    if [ ! -f "$tumor_bam" ]; then
        echo "ERROR: tumor_bam file $tumor_bam not found!" >&2
        exit 1
    fi
    freec -conf ${config_file}
    """
}

dbSNP_ch   = Channel.fromPath(params.freec.dbSNP, checkIfExists: true)
ref_ch     = Channel.fromPath(params.ref_fasta, checkIfExists: true)
target_ch  = Channel.fromPath(params.target_bed, checkIfExists: true)
workflow {
    main:
    // 1. 准备参考数据
    PREPARE_REFERENCE( file(params.ref_fasta), file(params.target_bed) )

    // 3. 加载性别信息并转换为全局 Map（单元素 Channel）
    input_channel = Channel.fromPath(params.gender_csv)
        | splitCsv(header: false, sep: ",")
        | map { id, path, gender -> tuple(id, file(path), gender) }   // 转换为键值对列表

    combined_ch = dbSNP_ch
    .combine(target_ch)
    .combine(ref_ch)

    .map { dbsnp, bed, ref -> tuple(dbsnp, bed, ref) }

    // 5. 生成配置 & 运行 FREEC（根据你的实际流程调整）
    def freec_config

    if ( params.normal_dir ) {
        freec_config = generate_freec_config( input_channel, PREPARE_REFERENCE.out, combined_ch, selected_control.control_path )
        RUN_FREEC( freec_config.config,input_channel, PREPARE_REFERENCE.out, combined_ch, selected_control.control_path )
    } else {
        freec_config = generate_freec_config( input_channel, PREPARE_REFERENCE.out, combined_ch, Channel.value("no_control") )
        RUN_FREEC( freec_config.config,input_channel, PREPARE_REFERENCE.out, combined_ch, Channel.value("no_control") )
    }

}
