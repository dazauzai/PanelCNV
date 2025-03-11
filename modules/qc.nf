process qc {
  tag "QC-${sample_id}"
  label 'process_low'
  container params.docker_image.fastqc

  input:
    tuple val(sample_id), path(fastq)
  output:
    path("*_fastqc.zip"), emit: qc_zip    // 输出 FastQC 的 ZIP 文件
    path("*.html"), emit: qc_html          // 输出日志文件

  publishDir "${params.out}/${sample_id}/qc", 
    mode: 'copy',  // 模式：复制文件（不修改原始文件）
    pattern: "*.{zip,html}"  // 仅复制 zip 和 html 文件

  script:
    """
    # 打印当前处理的样本 ID
    echo "Processing sample: ${sample_id}"

    # 对每个 fastq 文件运行 FastQC
    for file in ${fastq}; do
      fastqc -o . "\$file"
    done
    """
}
