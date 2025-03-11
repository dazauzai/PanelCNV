include { checkFiles } from './filescan.nf'
process aceess {
    tag "aceess"
    cpus 1
    label 'low_mem'
    input:
    path ref_fasta
    output:
    path("*.bed"), emit: bed
    script:
    """
    prefix=$(basename "\${ref_fasta}" | sed -E 's/\.(fa|fasta)$//')

    cnvkit.py access \${ref_fasta} -o "access.\${prefix}.bed"
    """
}

process bed_prepare {
    tag "bed_prepare"
    cpus 1
    memory '1 GB'
    label 'low_mem'
    container 'dazauzai/cnvkit_image:latest'
    input:
    tuple val(sample_id), val(tumor_bam)
    path bed
    path bait_bed
    output:
    path("*target.bed"), emit: target_bed
    path("*antitarget.bed"), emit: antitarget_bed
    script:
    """
    if [ ${params.cnvkit.func} == "amplicon"]; then
        cnvkit.py autobin basename(\${tumor_bam}) -t \${bait_bed} -m amplicon
    elif [ ${params.cnvkit.func} == "hybrid"]; then
        cnvkit.py autobin *.bam -t \${bait_bed} -g \${bed}
    else
        exit 1
    fi
    """
}

process bam_process {
    tag "bam_process"
    cpus 1
    memory '8 GB'
    label 'high_mem'
    container 'dazauzai/cnvkit_image:latest'
    publishDir "${params.output_dir}/cnvkit_cnn", pattern: "*.cnn", mode: 'copy'
    input:
    tuple val(sample_id), val(bam)
    path target_bed
    path antitarget_bed
    output:
    tuple val(sample_id), path("*targetcoverage.cnn"), path("*antitargetcoverage.cnn"), emit: cnn
    
    script:
    """
    echo "\${sample_id}"
    cnvkit.py coverage \${bam} -t \${target_bed} -o \${sample_id}.targetcoverage.cnn
    cnvkit.py coverage \${bam} -t \${antitarget_bed} -o \${sample_id}.antitargetcoverage.cnn
    """
}


process cnvkit_ref { 
    tag "cnvkit_ref"
    cpus 1
    memory '8 GB'
    label 'high_mem'
    container 'dazauzai/cnvkit_image:latest'
    input:
    tuple val(sample_id), path(target_cnn), path(antitarget_cnn)
    path target_bed
    path antitarget_bed
    path ref_fasta
    val func
    output:
    path("*.cnn"), emit: reference_cnn
    script:
    """
    if [ \${func} == "control" ]; then
        cnvkit.py reference ${params.output_dir}/cnvkit_cnn/*coverage.cnn -f ${ref_fasta} -o Reference.cnn
    elif [ \${func} == "flat" ]; then
        cnvkit.py reference -o FlatReference.cnn -f ${ref_fasta} -t ${target_bed} -a ${antitarget_bed} ${params.output_dir}/cnvkit_cnn/*coverage.cnn
    fi
    """
}

process cnvkit_cnv_calling {
    label 'high_mem'
    cpus 8
    memory '8 GB'
    container 'dazauzai/cnvkit_image:latest'
    publishDir "${params.output_dir}/cnvkit_cnv", pattern: "*.cnr", mode: 'copy'
    input:
    tuple val(sample_id), path(target_cnn), path(antitarget_cnn)
    path ref_cnn // 参考样本的 CNN 文件
    output:
    path("*.cnr"), emit: cnr
    script:
    """
    cnvkit.py fix ${target_cnn} ${antitarget_cnn} ${ref_cnn} -o "${sample_id}.cnr"
    if [ params.cnvkit.dplow == "yes" ]; then
        dplow="--drop-low-coverage"
    else
        dplow=""
    fi
    if [ param.cnvkit.dpout == "yes"]; then
        dpout="--drop-outliers"
    else
        dpout=""
    fi
    cnvkit.py segment "${sample_id}.cnr" -o "${sample_id}.cns" -m ${params.cnvkit.seg} \${dplow} \${dropout}
    cnvkit.py call "${sample_id}.cns" -o "${sample_id}.call.cns"
    cnvkit.py scatter "${sample_id}.cnr" -s "${sample_id}.call.cns"
    """
}

workflow {
    main:
    aceess(params.ref_fasta)
    def samples_tumor = checkFiles(params.tumor_bam)
    ch_tumor_input = Channel.from(
        samples_tumor.findAll { _, data -> data.type == 'bam' }  // 确保只处理 BAM
                  .collect { sample_id, data -> 
                      tuple(sample_id, data.files[0])
              }
    )
    bed_prepare(ch_tumor_input, access.bed, params.target_bed)
    tumor_cnn = bam_process(ch_tumor_input, bed_prepare.target_bed, bed_prepare.antitarget_bed)
    if ( params.cnvkit.reffunc == "control") {
        def samples_control = checkFiles(params.normal_bam)
        ch_control_input = Channel.from(
            samples_control.findAll { _, data -> data.type == 'bam' }  // 确保只处理 BAM
                      .collect { sample_id, data -> 
                          tuple(sample_id, data.files[0])
                  }
        )
        bam_process(ch_control_input, bed_prepare.target_bed, bed_prepare.antitarget_bed)
        cnvkit_ref(ch_control_input, bed_prepare.target_bed, bed_prepare.antitarget_bed, params.ref_fasta, Channel.value("control"))
    } elif ( params.cnvkit.reffunc == "flat") {
        cnvkit_ref(ch_tumor_input, bed_prepare.target_bed, bed_prepare.antitarget_bed, params.ref_fasta, Channel.value("flat"))
    } else {
        cnvkit_ref(ch_tumor_input, bed_prepare.target_bed, bed_prepare.antitarget_bed, params.ref_fasta, Channel.value("control"))
    }
    cnvkit_cnv_calling(tumor_cnn.cnn, cnvkit_ref.reference_cnn)
}
