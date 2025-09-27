#!/bin/bash
# ============================================================
# Iterative Pangenome Assembly Pipeline
# Author: Jayesh Jain
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

THREADS=80
MEM=100G

ACCESSIONS_LIST=$WORKDIR/accessions_list/accessions_r.txt
PREV_ACCESSIONS_LIST=$WORKDIR/accessions_list/prev_accessions_r.txt

BOWTIE2=/path/to/bowtie2
SAMTOOLS=/path/to/samtools
MASURCA=/path/to/masurca
BBMAP_REFORMAT=/path/to/bbmap/reformat.sh

# ====== START PIPELINE ======
while IFS= read -r accession && IFS= read -r prev_accession <&3; do
    
    echo ">>> Processing accession: $accession"

    # Define input files
    input_r1="${INPUT_DIR}/${accession}_1_paired.fastq.gz"
    input_r2="${INPUT_DIR}/${accession}_2_paired.fastq.gz"
    output_sam="${OUTPUT_DIR}/${accession}.sam"

    # Step 1: Add unaligned reads to reference
    cat ${REF_DIR}/${prev_accession}_h_updated.fasta \
        ${FILTER_DIR}/${prev_accession}_assembled_filtered.fasta \
        > ${REF_DIR}/${accession}_updated.fasta

    # Step 2: Fix duplicate headers iteratively (awk trick)
    awk '/^>/ { if($1 in seen) { $1 = $1 ++seen[$1]; } else { seen[$1]=0 } } 1' \
        ${REF_DIR}/${accession}_updated.fasta > ${REF_DIR}/${accession}_h_updated.fasta
    rm ${REF_DIR}/${accession}_updated.fasta

    # Step 3: Index updated reference
    $BOWTIE2-build --threads $THREADS ${REF_DIR}/${accession}_h_updated.fasta ${INDEX_DIR}/varunaindex

    # Step 4: Mapping with Bowtie2
    $BOWTIE2 -p $THREADS -x ${INDEX_DIR}/varunaindex -1 "$input_r1" -2 "$input_r2" -S "$output_sam"

    # Cleanup index files
    rm ${INDEX_DIR}/varunaindex*

    # Step 5: Extract unaligned reads
    $SAMTOOLS view -b -f 4 -o ${UNALIGNED_DIR}/${accession}.bam $output_sam

    # Step 6: Convert SAM → BAM & cleanup
    $SAMTOOLS view -@ $THREADS -b $output_sam -o ${OUTPUT_DIR}/${accession}.bam
    rm "$output_sam"

    # Step 7: Sort BAM by read name
    SORT_TMP=$(mktemp -d)
    $SAMTOOLS sort -@ 32 -T "$SORT_TMP" -n ${UNALIGNED_DIR}/${accession}.bam -o ${UNALIGNED_SORTED}/${accession}_sorted.bam

    # Step 8: Convert BAM → FASTQ
    $SAMTOOLS fastq -@ 32 \
        -1 ${UNALIGNED_FASTQ}/${accession}_R1.fastq \
        -2 ${UNALIGNED_FASTQ}/${accession}_R2.fastq \
        -0 ${UNALIGNED_FASTQ}/${accession}_unpaired.fastq \
        ${UNALIGNED_SORTED}/${accession}_sorted.bam

    # Step 9: Assembly with MaSuRCA
    $MASURCA -i ${UNALIGNED_FASTQ}/${accession}_R1.fastq,${UNALIGNED_FASTQ}/${accession}_R2.fastq \
             -t $THREADS \
             -o $ASSEMBLY_DIR \
             -g $ASSEMBLY_DIR

    # Move assembled genome
    mv ${ASSEMBLY_DIR}/CA/primary.genome.scf.fasta ${ASSEMBLED}/${accession}_assembled.fasta
    rm -r ${ASSEMBLY_DIR}/*

    # Step 10: Filter contigs > 500 bp
    $BBMAP_REFORMAT in=${ASSEMBLED}/${accession}_assembled.fasta \
                    out=${FILTER_DIR}/${accession}_assembled_filtered.fasta minlength=500

    echo ">>> Finished accession: $accession"

done < $ACCESSIONS_LIST 3< $PREV_ACCESSIONS_LIST
