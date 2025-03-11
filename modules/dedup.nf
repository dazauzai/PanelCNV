process mark_duplicates {
    tag "${sample_id}"
    label 'mark_duplicates'
    container params.docker_image.picard

    publishDir "${params.out_dir}/${sample_id}/dedup", 
        mode: 'copy',
        pattern: "*.{bam,txt}", // 根据实际输出类型调整
        overwrite: true

    input:
    tuple val(sample_id), path(bam_file)
    
    publishDir "${params.out}/${sample_id}/dedup", 
        mode: 'copy',  // 模式：复制文件（不修改原始文件）
        pattern: "*.{marked_bam,_marked_dup_metrics.txt}"  // 仅复制 zip 和 html 文件

    output:
    tuple val(sample_id), path("${sample_id}_marked.bam"), emit: marked_bam
    path("${sample_id}_marked_dup_metrics.txt"), emit: metrics

    script:
    """
    # 使用绝对路径确保容器内访问
    input_bam=\$(realpath ${bam_file})
    output_prefix=${sample_id}_marked

    java -jar /opt/picard/picard.jar MarkDuplicates \\
        I=\$input_bam \\
        O=\${output_prefix}.bam \\
        M=\${output_prefix}_dup_metrics.txt
    """
}
