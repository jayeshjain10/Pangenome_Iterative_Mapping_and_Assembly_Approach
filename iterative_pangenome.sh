#!/bin/bash
# ============================================================
# Iterative Pangenome Assembly Pipeline
# Description: Iterative mapping–assembly pipeline for 
#              constructing a pangenome (tested on Brassica juncea).
# Dependencies: Bowtie2, Samtools, MaSuRCA, BBMap, awk
# ============================================================

# ===== CONFIGURATION =====
WORKDIR=/path/to/iterative_assembly
INPUT_DIR=$WORKDIR/trimmed_fastq
OUTPUT_DIR=$WORKDIR/mapped_bam
REF_DIR=$WORKDIR/updated_genome
INDEX_DIR=$WORKDIR/index
UNALIGNED_DIR=$WORKDIR/unalign_reads
UNALIGNED_SORTED=$WORKDIR/unalign_reads_sorted
UNALIGNED_FASTQ=$WORKDIR/unalign_reads_fastq
ASSEMBLY_DIR=$WORKDIR/masurca_assembly
ASSEMBLED=$WORKDIR/assembled_file
FILTER_DIR=$WORKDIR/assembled_filtered

REFERENCE_ACCESSIONS_LIST=$WORKDIR/accessions_list/ref_accessions.txt
ACCESSIONS_LIST=$WORKDIR/accessions_list/accessions.txt

BOWTIE2=/path/to/bowtie2
SAMTOOLS=/path/to/samtools
MASURCA=/path/to/masurca
BBMAP_REFORMAT=/path/to/bbmap/reformat.sh

# ====== START PIPELINE ======
while IFS= read -r ref_accession && IFS= read -r accession <&3; do
    
    echo ">>> Processing accession: $accession"

    # Define input files
    input_r1="${INPUT_DIR}/${accession}_1_paired.fastq.gz"
    input_r2="${INPUT_DIR}/${accession}_2_paired.fastq.gz"
    output_sam="${OUTPUT_DIR}/${accession}.sam"

    # Step 1: Index updated reference
    $BOWTIE2/bowtie2-build --threads $THREADS ${REF_DIR}/${ref_accession}_updated.fasta ${INDEX_DIR}/ref_index

    # Step 2: Mapping with Bowtie2
    $BOWTIE2 -p $THREADS -x ${INDEX_DIR}/ref_index -1 "$input_r1" -2 "$input_r2" -S "$output_sam"

    # Cleanup index files
    rm ${INDEX_DIR}/ref_index*

    # Step 3: Extract unaligned reads
    $SAMTOOLS view -b -f 4 -o ${UNALIGNED_DIR}/${accession}.bam $output_sam

    # Step 4: Convert SAM → BAM & cleanup
    $SAMTOOLS view -@ $THREADS -b $output_sam -o ${OUTPUT_DIR}/${accession}.bam
    rm "$output_sam"

    # Step 5: Sort BAM by read name
    SORT_TMP=$(mktemp -d)
    $SAMTOOLS sort -@ $THREADS -T "$SORT_TMP" -n ${UNALIGNED_DIR}/${accession}.bam -o ${UNALIGNED_SORTED}/${accession}_sorted.bam

    # Step 6: Convert BAM → FASTQ
    $SAMTOOLS fastq -@ $THREADS \
        -1 ${UNALIGNED_FASTQ}/${accession}_R1.fastq \
        -2 ${UNALIGNED_FASTQ}/${accession}_R2.fastq \
        -0 ${UNALIGNED_FASTQ}/${accession}_unpaired.fastq \
        ${UNALIGNED_SORTED}/${accession}_sorted.bam

    # Step 7: Assembly with MaSuRCA
    $MASURCA -i ${UNALIGNED_FASTQ}/${accession}_R1.fastq,${UNALIGNED_FASTQ}/${accession}_R2.fastq \
             -t $THREADS \
             -o $ASSEMBLY_DIR \
             -g $ASSEMBLY_DIR

    # Move assembled genome
    mv ${ASSEMBLY_DIR}/CA/primary.genome.scf.fasta ${ASSEMBLED}/${accession}_assembled_contigs.fasta
    rm -r ${ASSEMBLY_DIR}/*

    # Step 8: Filter contigs > 500 bp
    $BBMAP_REFORMAT in=${ASSEMBLED}/${accession}_assembled_contigs.fasta \
                    out=${FILTER_DIR}/${accession}_assembled_contigs_filtered.fasta minlength=500

    
    # Step 9: Add unaligned reads to the reference
    cat ${REF_DIR}/${ref_accession}_updated.fasta \
        ${FILTER_DIR}/${ref_accession}_assembled_contigs_filtered.fasta \
        > ${REF_DIR}/${accession}_updated.fasta

    # Step 10: Fix duplicate headers iteratively (awk trick)
    awk '/^>/ { if($1 in seen) { $1 = $1 ++seen[$1]; } else { seen[$1]=0 } } 1' \
        ${REF_DIR}/${accession}_updated.fasta > ${REF_DIR}/${accession}_h_updated.fasta
    rm ${REF_DIR}/${accession}_updated.fasta
    echo ">>> Finished accession: $accession"

done < $ACCESSIONS_LIST 3< $REFERENCE_ACCESSIONS_LIST
