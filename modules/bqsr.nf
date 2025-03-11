include { checkFiles } from './filescan.nf'

process index {
    container 'dukegcb/bwa-samtools'
    tag "index"
    input:
    path ref_fasta
    output:
    path "ref_dir", type: 'directory', emit: out
    script:
    """
    bwa index $ref_fasta
    samtools faidx $ref_fasta
    mkdir -p ref_dir
    cp ${ref_fasta}* ref_dir/
    """
}


process bqsr {
    container 'broadinstitute/gatk'
    tag "bqsr"
    input:
    tuple val(sample_id) val(tumor_bam)
    path ref_dir
    path ref_fasta
    path vcf
    output:
    path "*BQSR.bam", emit: bam_out
    path "*.table", emit: bqsr_table
    script:
    """
    gatk BaseRecalibrator \
    -I \${tumor_bam} \
    -R "\${ref_dir}/\$(basename \${ref_fasta})" \
    --known-sites \${vcf} \
    -O "./\${sample_id}_RG_recal_data.table"

    gatk ApplyBQSR \
    -I \${tumor_bam} \
    -R "\${ref_dir}/\$(basename \${ref_fasta})" \
    --bqsr-recal-file "\${prefix}_RG_recal_data.table" \
     -O "./\${sample_id}_RG_BQSR.bam"
    """
}

workflow {
    main:
    def samples_tumor = checkFiles(params.tumor_bam)
    index(params.ref_fasta)
    bqsr(samples_tumor, index.out, Channel.of(file(params.ref_fasta)), Channel.of(file(params.bqsr.vcf)))
}