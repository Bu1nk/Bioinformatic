version 1.0

workflow MappingQC {
  meta {
    description: "Оценка качества картирования Illumina PE: FastQC, bwa mem, samtools, flagstat"
  }

  input {
    File reference_fasta
    File fastq_r1
    File fastq_r2
    String sample_name = "sample"
    Float mapped_threshold = 90.0
  }

  call IndexReference {
    input:
      ref = reference_fasta
  }

  call FastQC {
    input:
      r1 = fastq_r1,
      r2 = fastq_r2,
      sample = sample_name
  }

  call BwaMem {
    input:
      ref_files = IndexReference.indexed_ref,
      r1 = fastq_r1,
      r2 = fastq_r2,
      sample = sample_name
  }

  call SamToBam {
    input:
      sam = BwaMem.sam_file,
      sample = sample_name
  }

  call Flagstat {
    input:
      bam = SamToBam.bam_file,
      sample = sample_name
  }

  call ParseFlagstat {
    input:
      flagstat = Flagstat.flagstat_file,
      threshold = mapped_threshold
  }

  if (ParseFlagstat.mapping_ok) {
    call SortBam {
      input:
        bam = SamToBam.bam_file,
        sample = sample_name
    }

    call FreeBayes {
      input:
        ref = reference_fasta,
        bam = SortBam.sorted_bam,
        sample = sample_name
    }
  }

  output {
    Array[File] fastqc_reports = FastQC.reports
    File bam = SamToBam.bam_file
    File flagstat = Flagstat.flagstat_file
    Float mapped_percent = ParseFlagstat.mapped_percent
    Boolean mapping_ok = ParseFlagstat.mapping_ok
    String qc_status = ParseFlagstat.status_message
    File? vcf = FreeBayes.vcf
    File qc_summary = ParseFlagstat.summary_file
  }
}

task IndexReference {
  input {
    File ref
  }

  command <<<
    set -euo pipefail
    cp ~{ref} ref.fa
    bwa index ref.fa
  >>>

  output {
    Array[File] indexed_ref = glob("ref.fa*")
  }
}

task FastQC {
  input {
    File r1
    File r2
    String sample
  }

  command <<<
    set -euo pipefail
    mkdir -p fastqc_out
    fastqc -o fastqc_out -t 2 ~{r1} ~{r2}
  >>>

  output {
    Array[File] reports = glob("fastqc_out/*")
  }
}

task BwaMem {
  input {
    Array[File] ref_files
    File r1
    File r2
    String sample
  }

  command <<<
    set -euo pipefail
    for f in ~{sep=' ' ref_files}; do
      dest=$(basename "$f")
      if [ ! -e "$dest" ]; then ln -sf "$f" "$dest"; fi
    done
    bwa mem -t 4 ref.fa ~{r1} ~{r2} > ~{sample}.sam
  >>>

  output {
    File sam_file = "~{sample}.sam"
  }
}

task SamToBam {
  input {
    File sam
    String sample
  }

  command <<<
    set -euo pipefail
    samtools view -@ 2 -bS ~{sam} -o ~{sample}.bam
  >>>

  output {
    File bam_file = "~{sample}.bam"
  }
}

task Flagstat {
  input {
    File bam
    String sample
  }

  command <<<
    set -euo pipefail
    samtools flagstat ~{bam} > ~{sample}.flagstat.txt
  >>>

  output {
    File flagstat_file = "~{sample}.flagstat.txt"
  }
}

task ParseFlagstat {
  input {
    File flagstat
    Float threshold
  }

  command <<<
    set -euo pipefail
    MAPPED_LINE=$(grep -E ' mapped \(' ~{flagstat} | head -n 1)
    PERCENT=$(echo "$MAPPED_LINE" | sed -n 's/.*(\([0-9.]*\)%.*/\1/p')
    echo "$PERCENT" > mapped_percent.txt

    if awk -v p="$PERCENT" -v t="~{threshold}" 'BEGIN { exit !(p > t) }'; then
      echo "OK" > status.txt
      echo "Mapping quality OK: ${PERCENT}% mapped (threshold >~{threshold}%)" > summary.txt
    else
      echo "not OK" > status.txt
      echo "Mapping quality not OK: ${PERCENT}% mapped (threshold >~{threshold}%)" > summary.txt
    fi
  >>>

  output {
    Float mapped_percent = read_float("mapped_percent.txt")
    Boolean mapping_ok = read_string("status.txt") == "OK"
    String status_message = read_string("status.txt")
    File summary_file = "summary.txt"
  }
}

task SortBam {
  input {
    File bam
    String sample
  }

  command <<<
    set -euo pipefail
    samtools sort -@ 2 -o ~{sample}.sorted.bam ~{bam}
    samtools index ~{sample}.sorted.bam
  >>>

  output {
    File sorted_bam = "~{sample}.sorted.bam"
  }
}

task FreeBayes {
  input {
    File ref
    File bam
    String sample
  }

  command <<<
    set -euo pipefail
    freebayes -f ~{ref} ~{bam} > ~{sample}.vcf
  >>>

  output {
    File vcf = "~{sample}.vcf"
  }
}
