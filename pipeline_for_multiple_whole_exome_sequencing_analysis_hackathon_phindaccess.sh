#!/bin/sh
**********************************************************************************************************************
###Hello!!
###This is our newly developed pipeline for the simultaneaous analysis of multiple human whole exome sequences generated by an Illumina platform.

###This pipeline was developed as a result of our work during the hackathon: Study of genetic susceptibility to COVID-19 and SARS-CoV-2 human host-pathogen interactions, organized in the frame of Phindaccess project (https://phindaccess.org/)

###For now, the pipeline is suitable for the analysis of up to 30 whole exome sequences.

###Team members: Hamza Dallali, Yosr Hamdi, Afef Rais, Imen Moumni, Manel Gharbi.

**********************************************************************************************************************

##Creation of a conda environment

conda create --name wes_analysis
conda activate wes_analysis

**********************************************************************************************************************

##Installing necessary tools for the execution of the pipeline

conda install -c bioconda fastqc
conda install -c bioconda trimmomatic
conda install -c bioconda bwa
conda install -c bioconda samtools=1.13

wget https://github.com/broadinstitute/gatk/releases/download/4.2.6.1/gatk-4.2.6.1.zip
unzip /home/$USER/Downloads/gatk-4.2.6.1.zip -d /home/$USER/Desktop/bioinformatics/bioinformatic_tools/
export PATH="/home/$USER/Desktop/bioinformatics/bioinformatic_tools/gatk-4.2.6.1/:$PATH"

*******************************************************************************************************************

##Definition of variables for the path of the directories containing the raw data, the necessary files for the analysis and the downstream files resulting from the execution of the pipeline

#An example of the apth to the work directory
work_directory="/home/$USER/Desktop/bioinformatics/wes_analysis_hackathon"

#Path to the directory containing the reference genome. In this pipeline, we used hg19 reference genome (it can be downloaded using the following command: "wget hgdownload.cse.ucsc.edu/goldenpath/hg19/bigZips/hg19.fa.gz")

reference_genome_directory="/home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/reference_genome/hg19"

#Path to vcf files containing known snps and indels, that can be downloaded from GATK resource bundle.
known_sites_snps_indels_hg19_path="/home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/known_sites_snps_indels_hg19"

#Path to a bed file for the captured regions during the library prepration, prior to whole exome sequencing.
bed_file_path="/home/$USER/Desktop/bioinformatics/targeted_bed_file/example_bed_file.bed"

#Path to raw fastq files
fastq_directory="/home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/fastq"

#Path to the resukts of the fastq files quality control
fastq_quality_control_path="/home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/wes_quality_control"

#Path to the alignment files
alignment_path="/home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/wes_alignment"

#Path to the bam processing files
bam_processing_path="/home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/wes_bam_processing"

#Path to the haplotype caller results
haplotype_caller_results_path="/home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/wes_haplotype_caller_results"

#Path to the genotype GVCF results, containing the final and filtered vcf file
genotype_gvcf_results_path="/home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/wes_genotype_gvcf_results"

*********************************************************************************************************************

##Creation of specific work directories to inculde the resuts of the pipeline

mkdir /home/$USER/Desktop/bioinformatics/wes_analysis_hackathon
mkdir /home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/wes_quality_control
mkdir /home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/wes_alignment
mkdir /home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/wes_bam_processing
mkdir /home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/wes_haplotype_caller_results
mkdir /home/$USER/Desktop/bioinformatics/wes_analysis_hackathon/wes_genotype_gvcf_results

********************************************************************************************

echo "Now we are ready, let's start the analysis!"

*******************************************************************************************************************

##Run quality control on raw data using fastqc

for file in $fastq_directory/*.fastq.gz
do
fastqc $file --outdir $fastq_quality_control_path
done


*******************************************************************************************************************

##Trimming adapters and low quality bases using trimmomatic

quality_control_results_path=fastq_quality_control_path
for fastq_file_1_path in $fastq_directory/*r1.fastq.gz
do 
fastq_directory_path=$(dirname $fastq_file_1_path)
fastq_file_1_name=$(basename $fastq_file_1_path)
fastq_file_2_path_without_read_number_and_extension=${fastq_file_1_path%%r1.fastq.gz}
sample_name_without_read_number_and_extension=$(basename $fastq_file_2_path_without_read_number_and_extension)
trimmomatic PE \ 
            $fastq_file_1_path \
            $fastq_file_2_path_without_read_number_and_extension"r2.fastq.gz" \
            $fastq_quality_control_path/$sample_name_without_read_number_and_extension"trimmed_paired_1.fastq.gz" \
            $fastq_quality_control_path/$sample_name_without_read_number_and_extension"trimmed_unpaired_1.fastq.gz" \
            $fastq_quality_control_path/$sample_name_without_read_number_and_extension"trimmed_paired_2.fastq.gz" \
            $fastq_quality_control_path/$sample_name_without_read_number_and_extension"trimmed_unpaired_2.fastq.gz" \
            ILLUMINACLIP:/home/$USER/miniconda3/envs/wes_analysis/share/trimmomatic-0.39-2/adapters/TruSeq3-PE.fa:2:30:10 \
            SLIDINGWINDOW:4:15 MINLEN:36
done

********************************************************************************************************************

##Run quality control on trimmed data using fastqc

for file in $fastq_quality_control_path/*trimmed_paired*
do
fastqc $file --outdir $fastq_quality_control_path
done

********************************************************************************************************************

##Mapping the reads against the reference genome using bwa

#Indexing the reference genome

index_file=$reference_genome_directory/ucsc.hg19.fasta.bwt
if test -f "$index_file"; then
    echo "reference genome index files exist."
else
    bwa index $reference_genome_directory/ucsc.hg19.fasta
fi

#Alignment

echo "Mapping the reads against the reference genome using bwa"

for trimmed_fastq_1_path in $fastq_quality_control_path/*trimmed_paired_1.fastq.gz
do
trimmed_fastq_file_2_path_without_read_number_and_extension=${trimmed_fastq_1_path%%_trimmed_paired_1.fastq.gz}
sample_name_without_read_number_and_extension=$(basename $trimmed_fastq_file_2_path_without_read_number_and_extension)
bwa mem -t 2 -M \
        -R "@RG\tID:$sample_name_without_read_number_and_extension\tSM:$sample_name_without_read_number_and_extension\tPL:ILLUMINA" \
        $reference_genome_directory/ucsc.hg19.fasta \
        $trimmed_fastq_1_path $trimmed_fastq_file_2_path_without_read_number_and_extension"_trimmed_paired_2.fastq.gz" > $alignment_path/$sample_name_without_read_number_and_extension".sam"
done

******************************************************************************************************************

##Converting sam files to bam format files 

echo "Converting sam files to bam format files"

for sam_file_path in $alignment_path/*.sam 
do  
alignment_file_path_without_extension=${sam_file_path%%.sam}
samtools view -Sb $sam_file_path > $alignment_file_path_without_extension".bam"
done

*****************************************************************************************************************

##Sorting bam files

echo "Sorting bam files"

for bam_file_path in $alignment_path/*.bam 
do
bam_file_path_without_extension=${bam_file_path%%.bam}
sample_name=$(basename $bam_file_path_without_extension)
samtools sort $bam_file_path -o $bam_processing_path/$sample_name".sorted.bam"
done

****************************************************************************************************************

##Creation of index file of the fasta reference file for GATK algorithm

fai_index_file=$reference_genome_directory/ucsc.hg19.fasta.fai
if test -f "$fai_index_file"; then
    echo "reference genome index file .fai exists."
else
    samtools faidx $reference_genome_directory/ucsc.hg19.fasta
fi

***************************************************************************************************************

##Creation of dictionnary of the fasta reference file for GATK algorithm

dict_file=$reference_genome_directory/ucsc.hg19.dict
if test -f "$dict_file"; then
    echo "reference genome dictionnary file exists."
else
    gatk CreateSequenceDictionary -R $reference_genome_directory/ucsc.hg19.fasta -O $reference_genome_directory/ucsc.hg19.dict
fi

**************************************************************************************************************

##Indexing sorted bam files, and checking their qualities and mate information using GATK

echo "Indexing sorted bam files, and checking their qualities and mate information"

for sorted_bam_file_path in $bam_processing_path/*.sorted.bam
do
sorted_bam_file_path_without_extension=${sorted_bam_file_path%%.sorted.bam}
samtools index $sorted_bam_file_path
gatk ValidateSamFile -I $sorted_bam_file_path MODE=SUMMARY
gatk FixMateInformation -I $sorted_bam_file_path \
     -O $sorted_bam_file_path_without_extension".sorted.fixmate.bam"  \
      VALIDATION_STRINGENCY=LENIENT
done

****************************************************************************************************************

##Indexing fixmate bam files using samtools, and marking duplicates using gatk

echo "Indexing fixmate bam files using samtools, and marking duplicates using gatk"

for fixmate_bam_file_path in $bam_processing_path/*.sorted.fixmate.bam
do
fixmate_bam_file_path_without_extension=${fixmate_bam_file_path%%.sorted.fixmate.bam}
samtools index $fixmate_bam_file_path
gatk MarkDuplicates \
     I=$fixmate_bam_file_path \
     O=$fixmate_bam_file_path_without_extension".sorted.fixmate.dedup.bam" \
     REMOVE_DUPLICATES=false \
     M=$fixmate_bam_file_path_without_extension"_mark_duplicates_report.txt" \
     VALIDATION_STRINGENCY=LENIENT CREATE_INDEX=true
done

******************************************************************************************************************

##Base quality score recalibration using GATK

echo "Performing base quality score recalibration using GATK"

#Analyze patterns of covariation in the sequence dataset

for dedup_bam_file_path in $bam_processing_path/*.sorted.fixmate.dedup.bam
do
dedup_bam_file_path_without_extension=${dedup_bam_file_path%%.sorted.fixmate.dedup.bam}
sample_name=$(basename $dedup_bam_file_path_without_extension)
echo "Generating recalibration table for $sample_name"
gatk BaseRecalibrator \
     -R $reference_genome_directory/ucsc.hg19.fasta \
     -I $dedup_bam_file_path \
     --known-sites $known_sites_snps_indels_hg19_path/dbsnp_137.hg19.excluding_sites_after_129.vcf \
     --known-sites $known_sites_snps_indels_hg19_path/Mills_and_1000G_gold_standard.indels.hg19.vcf \
     --known-sites $known_sites_snps_indels_hg19_path/1000G_phase1.indels.hg19.vcf \
     -O $dedup_bam_file_path_without_extension".recal_data.table"


#Apply recalibration on the bam files

echo "Apply Base Quality Score Recalibration for $sample_name"

gatk ApplyBQSR \
     -R $reference_genome_directory/ucsc.hg19.fasta \
     -I $dedup_bam_file_path \
     --bqsr-recal-file $dedup_bam_file_path_without_extension".recal_data.table" \
     -O $dedup_bam_file_path_without_extension".recalibrated.bam"
done

*****************************************************************************************************************

##Sorting to indexing the recalibrated bam files using samtools

echo "Sorting to indexing the recalibrated bam files using samtools"

for recalibrated_bam_file_path in $bam_processing_path/*.recalibrated.bam
do
recalibrated_bam_file_path_without_extension=${recalibrated_bam_file_path%%.recalibrated.bam}
samtools sort $recalibrated_bam_file_path -o $recalibrated_bam_file_path_without_extension".recalibrated.sorted.bam"
samtools index $recalibrated_bam_file_path_without_extension".recalibrated.sorted.bam"
done

*****************************************************************************************************************

##variant calling

#Call variants per-sample with GATK HaplotypeCaller tool

echo "Call variants per-sample with GATK HaplotypeCaller tool"

for final_bam_file_path in $bam_processing_path/*.recalibrated.sorted.bam
do
final_bam_file_path_without_extension=${final_bam_file_path%%.recalibrated.sorted.bam}
sample_name=$(basename $final_bam_file_path_without_extension)
gatk --java-options "-Xmx4g" HaplotypeCaller \
     -R $reference_genome_directory/ucsc.hg19.fasta \
     -I $final_bam_file_path \
     -O $haplotype_caller_results_path/$sample_name".g.vcf.gz" \
     -ERC GVCF \
     -L $bed_file_path
done


#Consolidate GVCFs with GATK GenomicsDBImport

echo "Consolidate GVCFs with GATK GenomicsDBImport"

gvcf_files=''
for gvcf_file_path in $haplotype_caller_results_path/*.g.vcf.gz
do
gvcf_directory_path=$(dirname $gvcf_file_path)
gvcf_file_name=$(basename $gvcf_file_path)
gvcf_file_name_without_extension=${gvcf_file_name%%.g.vcf.gz}
gvcf_files=${gvcf_files}" -V "$gvcf_directory_path"/"$gvcf_file_name
done

gatk --java-options "-Xmx4g -Xms4g" GenomicsDBImport \
     $gvcf_files \
     --genomicsdb-workspace-path $work_directory/my_gvcf_database \
     -L $bed_file_path

#Joint-Call Cohort with GATK GenotypeGVCFs

echo "Joint-Call Cohort with GATK GenotypeGVCFs"

gatk --java-options "-Xmx4g" GenotypeGVCFs \
     -R $reference_genome_directory/ucsc.hg19.fasta \
     -V gendb://$work_directory/my_gvcf_database \
     -O $genotype_gvcf_results_path"/all_samples_variant_calls.vcf.gz" \
     -L $bed_file_path

*****************************************************************************************************************

##Hard filter a cohort callset with VariantFiltration (Applied in small cohort callsets, e.g. less than thirty exomes)

echo "Hard filter a cohort callset with VariantFiltration"

#Subset to SNPs-only callset with GATK SelectVariants

gatk SelectVariants \
    -V $genotype_gvcf_results_path/all_samples_variant_calls.vcf \
    -select-type SNP \
    -O $genotype_gvcf_results_path/all_samples_snps.vcf
    
#Subset to indels-only callset with GATK SelectVariants

gatk SelectVariants \
    -V $genotype_gvcf_results_path/all_samples_variant_calls.vcf \
    -select-type INDEL \
    -O $genotype_gvcf_results_path/all_samples_indels.vcf

#Hard-filter SNPs on multiple expressions using GATK VariantFiltration

gatk VariantFiltration \
    -V $genotype_gvcf_results_path/all_samples_snps.vcf \
    -filter "QD < 2.0" --filter-name "QD2" \
    -filter "QUAL < 30.0" --filter-name "QUAL30" \
    -filter "SOR > 3.0" --filter-name "SOR3" \
    -filter "FS > 60.0" --filter-name "FS60" \
    -filter "MQ < 40.0" --filter-name "MQ40" \
    -filter "MQRankSum < -12.5" --filter-name "MQRankSum-12.5" \
    -filter "ReadPosRankSum < -8.0" --filter-name "ReadPosRankSum-8" \
    -O $genotype_gvcf_results_path/all_samples_snps_filtered.vcf
    
#Hard-filter indels on multiple expressions using GATK VariantFiltration

gatk VariantFiltration \ 
    -V $genotype_gvcf_results_path/all_samples_indels.vcf \ 
    -filter "QD < 2.0" --filter-name "QD2" \
    -filter "QUAL < 30.0" --filter-name "QUAL30" \
    -filter "FS > 200.0" --filter-name "FS200" \
    -filter "ReadPosRankSum < -20.0" --filter-name "ReadPosRankSum-20" \ 
    -O $genotype_gvcf_results_path/all_samples_indels_filtered.vcf
    
*******************************************************************************************************************

##Merge filtered snps and indels in a single filtered vcf file for all samples

gatk MergeVcfs \
    -I $genotype_gvcf_results_path/all_samples_snps_filtered.vcf \
    -I $genotype_gvcf_results_path/all_samples_indels_filtered.vcf \
    -O $genotype_gvcf_results_path/all_samples_variants_calls_filtered.vcf        
    
******************************************************************************************************************

echo "The analysis has completed successfully!!!"    



