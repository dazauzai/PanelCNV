/**
 * 检查输入目录中的文件，返回样本信息
 */

def checkFiles(String inputDir) {
    def samples = [:]
    def dir = new File(inputDir)

    if (!dir.exists() || !dir.isDirectory()) {
        exit 1, "ERROR: Directory $inputDir does not exist or is not a directory"
    }

    dir.eachFile { file ->
        if (file.isFile()) {
            // 跳过索引文件和R2文件
            if (file.name.toLowerCase().endsWith('.bai') || 
                file.name.toLowerCase().endsWith('.cai') ||
                isR2FastqFile(file.name)) {
                return // Skip index files and R2 files
            }
            
            def fileName = file.name
            def (type, baseName) = parseFileType(fileName)
            
            if (!type) {
                exit 1, "ERROR: Unsupported file type: $fileName"
            }

            if (type == 'fastq') {
                handleFastqFile(file, samples)
            } else {
                handleOtherFile(file, type, baseName, samples)
            }
        }
        
    }

    // 确保 samples 中存储的是 File 对象
    samples.each { sampleID, info ->
    info.files = info.files.collect { filePath ->
        // 如果 filePath 是字符串，创建 File 对象并获取绝对路径
        def file = (filePath instanceof String) ? new File(filePath) : filePath
        file.getAbsolutePath()
    }
}

    
    return samples
}



/**
 * 判断是否为R2文件（新增辅助方法）
 */
private Boolean isR2FastqFile(String fileName) {
    // 匹配_R2/_2/R2_等常见模式，忽略大小写
    return fileName =~ /(?i)(_R2|_2|R2_)[^\/]*\.(fastq|fq)(\.gz)?$/
}

/**
 * 处理fastq文件并验证配对（保持原逻辑）
 */
private def handleFastqFile(File file, Map samples) {
    def (prefix, r2Path) = findPairedFile(file)
    
    if (!new File(r2Path).exists()) {
        exit 1, "ERROR: Missing paired-end file for: ${file.name}"
    }

    def sampleId = prefix
    if (samples.containsKey(sampleId)) {
        exit 1, "ERROR: Duplicate sample ID: $sampleId"
    }

    samples[sampleId] = [
        type: 'fastq',
        files: [file.path, r2Path]
    ]
}

/**
 * 解析文件类型和基础名称
 */
private def parseFileType(String fileName) {
    def matcher = fileName =~ /(?i)^(.+?)(_R?1)?(_L\d+)?\.(bam|cram|bed|fastq|fq)(\.gz)?$/
    if (matcher.matches()) {
        def ext = matcher.group(4).toLowerCase()
        def type = (ext in ['fastq', 'fq']) ? 'fastq' : ext
        def base = matcher.group(1)
        return [type, base]
    }
    return [null, null]
}


/**
 * 查找配对的fastq文件
 */
private def findPairedFile(File file) {
    def fileName = file.name
    def matcher = fileName =~ /(?i)^(.+?)(_R?1)(_L\d+)?\.(fastq|fq)(\.gz)?$/
    
    if (!matcher.matches()) {
        exit 1, "ERROR: Invalid FASTQ filename format: $fileName"
    }

    def prefix = matcher.group(1)
    def lane = matcher.group(3) ?: ""
    def suffix = ".${matcher.group(4)}${matcher.group(5) ?: ''}"
    
    def r2FileName = "${prefix}${matcher.group(2).replace('1', '2')}${lane}${suffix}"
    def r2Path = new File(file.parentFile, r2FileName).path
    
    return [prefix, r2Path]
}

/**
 * 处理其他类型文件
 */
private def handleOtherFile(File file, String type, String baseName, Map samples) {
    if (samples.containsKey(baseName)) {
        exit 1, "ERROR: Duplicate sample ID: $baseName"
    }

    samples[baseName] = [
        type: type,
        files: [file.path]
    ]
}
