// pipeline/main.nf

// 导入所有模块
include { checkFiles } from './modules/filescan.nf'
include { qc } from './modules/qc.nf'
include { mark_duplicates } from './modules/dedup.nf'
include { generate_config, run_freec, collect_results, prepare_reference, select_control_sample } from './modules/freec.nf'
// --------------------------
// 子流程定义（可独立运行）
// --------------------------


workflow {
    // 调用 checkFiles 方法获取样本信息
    def samples = checkFiles(params.input)

    // 打印调试信息
    samples.each { sampleID, info -> 
        println "DEBUG: $sampleID → ${info.files}"
    }

    // 将 samples 转换为 Channel
    dedup_channel = Channel.fromList(
        samples.collect { sampleID, info -> 
            tuple(sampleID, info.files)  // 创建 tuple (sample_id, fastq 文件列表)
        }
    )

    // 调用 mark_duplicates 进程，传入 Channel
    mark_duplicates(dedup_channel)
}

// 质量检测（如果需要，可以启用以下代码）
/*
workflow {
    // 调用 checkFiles 方法获取样本信息
    def samples = checkFiles(params.input)

    // 打印调试信息
    samples.each { sampleID, info -> 
        println "DEBUG: $sampleID → ${info.files}"
    }

    // 将 samples 转换为 Channel
    qc_channel = Channel.fromList(
        samples.collect { sampleID, info -> 
            tuple(sampleID, info.files)  // 创建 tuple (sample_id, fastq 文件列表)
        }
    )

    // 调用 qc 进程，传入 Channel
    qc(qc_channel)
}
*/
