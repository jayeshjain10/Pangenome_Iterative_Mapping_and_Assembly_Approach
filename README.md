# Pangenome-Iterative-Assembly-Pipeline
Iterative mapping–assembly pipeline for pangenome construction using short-read data.

# Pangenome Iterative Assembly Pipeline

This repository provides a **Bash-based iterative mapping–assembly pipeline** for constructing a pangenome.  
It was developed and tested on *Brassica juncea* accessions, but the workflow can be adapted to other species.  

---

## 🚀 Features
- Iterative reference updating with unaligned reads  
- Read mapping using **Bowtie2**  
- Assembly of unmapped reads using **MaSuRCA**  
- Filtering of assembled contigs with **BBMap**  
- Generates progressively updated references to build a pangenome  

---

## ⚙️ Requirements
Install the following tools and ensure they are available in your `$PATH`:
- [Bowtie2](http://bowtie-bio.sourceforge.net/bowtie2/index.shtml)  
- [Samtools](http://www.htslib.org/)  
- [MaSuRCA](https://github.com/alekseyzimin/masurca)  
- [BBMap](https://jgi.doe.gov/data-and-tools/bbtools/)  

---

## 📂 Input
- Paired-end FASTQ files (`*_R1.fastq.gz` and `*_R2.fastq.gz`)  
- A starting reference genome in FASTA format  
- Two text files listing accessions and previous accessions (to maintain iteration order)  

---

## 📤 Output
- Updated reference genome for each iteration  
- BAM files of mapped and unmapped reads  
- Unaligned reads in FASTQ format  
- Assembled contigs (>500 bp)  
- Final filtered assemblies for inclusion in the pangenome  

---

