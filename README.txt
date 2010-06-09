Illumina (Solexa) Production Pipeline Information

(Last Modified : May 26,2010)

This page describes various stages in Illumina (Solexa) production pipeline,
analysis results, how to interpret these results.

Pipeline Steps

1. Sequencing

There are currently four sequencing instruments namely, EAS034, EAS376,
HSQ-700142 and HSQ-700166. HSQ are Hi-Seq sequencers. EAS* are GA2 sequencers.
These instruments write the base calls data (RTA processing results) to
/stornext/snfs5/next-gen/Illumina/Instruments. There is a unique directory per
instrument. Images and intensity data are not copied to the cluster.

2. Data transfer to the cluster

For further analysis (such as sequence building and alignment with the
reference), the RTA data is copied to the ardmore cluster. All subsequent
analyses are performed at ardmore. The volumes where sequencers copy data are

Sequencer Network Volume
EAS034      /stornext/snfs5/next-gen/Illumina/Instruments/EAS034
EAS376      /stornext/snfs5/next-gen/Illumina/Instruments/EAS376
HSQ-700142  /stornext/snfs5/next-gen/Illumina/Instruments/HSQ-700142
HSQ-700166  /stornext/snfs5/next-gen/Illumina/Instruments/HSQ-700166

Early detection analysis from images is not performed anymore.

3. GERALD analysis

After sequencing operation completes and all the base calls data is copied to
respective destination volumes, GERALD analysis is started. GERALD step
generates sequence files, performs the alignment with the reference and computes
alignment results. Depending on the instrument and the number of cycles, it
could take anywhere from a few hours to several days to finish.

4. Upload analysis results to LIMS

After completion of the analysis, the summary files, and the summary of the
results are uploaded to LIMS.

5. Calculating uniqueness of reads

This is an optional step where sequence files produced in GERALD step are
analyzed and a percentage of unique reads is calculated.

6. Mini analysis

Since cluster volumes have finite capacity, it is necessary to preserve only the
minimum subset of analysis results that will be required in near future. Mini
analysis is performed to achieve that. It saves the summary files, sequence
files, alignment files and IVC plots. Everything else is prepared for archival
and removal from these volumes.

7. Archiving and removing data

Once mini analysis is completed, the RTA and analysis data (except mini
analysis) is archived and removed from the corresponding volumes in order to
keep sufficient free disk space for subsequent analyses.

Starting GERALD Analysis

Pre-requisite : It is necessary to ensure that the sequencing run is over and
all the relevant data (base calls data) has been copied to the destination
volume. Illumina software dumps several empty files to indicate these conditions

(i) Run.completed: Indicates that sequencing is complete - For paired flowcells,
                    it will be generated at the end of each read
(ii) Basecalling_Netcopy_complete_SINGLEREAD.txt: Indicates that base calls
                    results are copied to the cluster for a fragment flowcell
(iii) Basecalling_Netcopy_complete_READ1.txt: Indicates that base calls results for
                    read1 are copied for a paired flowcell
(iv) Basecalling_Netcopy_complete_READ2.txt:  Indicates that base calls results for
                    read2 are copied for a paired flowcell

Presence of these files can be used to automatically start GERALD analysis.

Things to know about GERALD

a. Configuration file : Illumina software (CASAVA) reads GERALD configuration
from a text file (config.txt). A configuration file describes various analysis
related parameters such as lane number(s) to analyze, reference paths for
alignment, number of cycles, type of analysis to start (i.e., paired or
fragment) etc. Creating this file is the first step in running GERALD.

b. GERALD directory : CASAVA creates a unique GERALD directory per each run. A
GERALD directory is created as a child-directory under the "base calls"
directory. It writes the makefile which contains the required targets to run
GERALD there. CASAVA software also performs some tests on this directory to
ensure that all parameters are correct.

c. Running GERALD : After GERALD directory is created, the user can navigate to
this directory and invoke the "make" command to start GERALD.

Executing the Pipeline

Several scripts have been created to automate various pipeline tasks. They are
located at /stornext/snfs5/next-gen/Illumina/ipipe/bin and
/stornext/snfs5/next-gen/Illumina/ipipe/lib. GERALD_driver.rb is the main entry
point to start the pipeline.

1. GERALD_Driver.rb creates the configuration file (config.txt) and places it
under /stornext/snfs5/next-gen/Illumina/goats/YYYY/MM/DD/FC-Lane, where

YYYY     4-digit year
MM       2-digit month
DD       2-digit date
FC-Lane	 Flowcell name with lane

It also creates a BASH script file "generate_makefiles.sh" that contains BASH
commands to create GERALD directory.

2. GERALD_Driver.rb executes "generates_makefiles.sh" and verifies that GERALD
directory was properly created.

3. The user can navigate to the GERALD directory, and execute the make commands
to start GERALD.

4. Starting GERALD_Driver.rb

GERALD analysis requires several run related parameters such as reference paths,
number of cycles. Thus, GERALD_Driver.rb can run in two modes, where the user
can provide these parameters on the command line, or it can connect to LIMS and
find the required parameters. Sample usage is listed below :

Usage:

Scenario 1, Obtaining information from LIMS 
  ruby GERALD_Driver.rb  FlowCell  LaneNumbers 

Scenario 2, Providing flowcell info on command line 
  ruby GERALD_Driver.rb FlowCell LaneNumbers NumCycles  FCType  ReferencePath   
  FCType    - Specify paired if FC is paired, otherwise fragment

5. Post run steps

Pipeline steps such as sending result summary via email, uploading Summary.htm
to LIMS, uploading analysis results to LIMS, performing uniqueness analysis and
starting mini analysis are undertaken via a collection of ruby scripts contained
in post_run_cmd.rb. The script post_run_cmd.rb is automatically run by CASAVA
since the POST_RUN_COMMAND configuration option points to it.

6. Archiving data

Once complete flowcell is analyzed and mini-analysis is completed, it should be
archived and everything but mini-analysis should be deleted from the volumes.
This should be done manually.

Exploiting Parallelization in GERALD alignment

GERALD stage uses ELAND version 2 algorithm for alignment. Several eland
processes concurrently align subset of the reads to the references. Alignment
times can be reduced if we can optimize the number of concurrently running
processes vs number of reads that each process aligns. Through several email
exchanges with Illumina we learnt the following

a. Parameter ELAND_SET_SIZE in GERALD configuration file controls the number of
eland processes.
b. For GA2 sequencers, its default value is 40. The number of concurrent processes
   for GA2 is determined by the formula 120/ELAND_SET_SIZE.
c. For Hi-Seq, there's no default value. However, Illumina recommends its value to
d. Each eland process requires a minimum 2G RAM. Thus, the number of concurrent
   processes should be limited based on available memory.
e. Each eland process should align less than 13 million reads. This is guaranteed
   as long as we use ELAND_SET_SIZE <=4 for hi-seq, and <=40 for GA2.
f. Each eland process has to load the complete reference in its own address space,
   it is not shared between processes. So, running a very large number of concurrent
   eland processes may actually be inefficient.

Pipeline software needs to be extended to set the desired value of ELAND_SET_SIZE
 based on type of sequencer.

Analysis Results

We retain the following files after the analysis is completed.

1. Sequence files

A sequence file contains the sequences and the quality values of the sequences
for all the reads the pass the filter (To be explained better). A typical
sequence file has entries similar to what is shown below

@USI-EAS376_0001:2:1:0:1137#0/2 
CCTCGTGTTAGGGGAGGGGTACAACATTTTATTTTGGTTATAAAAAATAAAGAACATATGGTCAACTGGGGCAAATGTAAACAGGGTAGGAACAA 
+USI-EAS376_0001:2:1:0:1137#0/2 
cccccWccf`]c]cV^bH]LTTSOSVZ_^_bcffbc\cc_eNe^JQTTSQXVEVSO\K[[[S`_JS\__c]G]bOOV[^_SSTcBBBBBBBBBBB 

Lines 1 and 3 are the Read ID with the mapping information. Line 2 is the
sequence and line 4 is the quality for the sequence.

2. Export files

An export file contains the final alignment results, sequence string, quality
string and additional information such as whether the read passed quality
filtering. Typical entries are listed below. For more information, see CASAVA
user guide "GERALD Output Files".

USI-EAS376      1       5       120     19875   17290   0       1
NNAACGATTCTGTCAAAAACTGACGCGTTGGATGAGGAGAAGTGGCTTAATATACTTGGCACGTTCGTCAAGGACTGGTTTAGAGATGAGTCACA
BBFFFJHHHH``````L`````T``````````````L````````````NKGGGHHIII`````LLLLOT``L`T```BBBBBBBBBBBBBBBB
PhiX_plus_SNP.fa      199     F   CT51G30T10   419    N
USI-EAS376      1       5       120     19875   17130   0       1
NNTTGCTGCTGCATTTCCTGAGCTTAATGCTTGGGAGCGTGCTGGTGCTGATGATTCCTCTGCTGGTATGGTTGACGCCGGATTGGAGAATCAAA
BBFFFFFFFF``````````LTTTT`````````LHLOLHLOOLL`````BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
PhiX_plus_SNP.fa      3290    F   TC51C30T10   304    N
USI-EAS376      1       5       120     19875   5309    0       1
NNCCAAGCAACAGCAGGTTTCCGAGATTATGCGCCAAATGCTTACTCAAGCTCGAACGGCTGGTCAGTATTTTACCAATGACCACATCAAAGAAA
BBFFFFFFFF````L````````````T```````````````L``````BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
PhiX_plus_SNP.fa      3587    F   TT51A30A10    307

3. IVC Plots

These are png images generated during RTA. (To be explained)

4. Summary file

A summary file describes the analysis summary for the specified lanes. It has
several sections that describe the parameters of the sequencing run and the
results. For example, Lane Parameter Summary section describes the alignment
algorithm used, number of cycles in the sequencing run, number of tiles, and the
chastity threshold. Lane Results Summary section describes the lane yield (in
kbases), number of clusters (both raw and purity filtered), percentage
alignment, alignment score, alignment error, and percentage intensity after 20
cycles. Finally, Expanded Lane Summary contains phasing and prephasing
percentage, percentage of data retained after filtering, alignment percentage
and error percentage (after purity filtering), and average intensity for a few
cycles. A sequencing run can be evaluated based on the values of these
parameters.

Potential Enhancements to the Pipeline

1. Saving results as BAM files

As a result of GERALD analysis, several files are generated in each GERALD
directory. Typically this directory contains sequence files, alignment files,
summary files and the intensity plots. As explained earlier, a sequence file
contains just the reads and their qualities. An alignment file contains the read
name, the sequence and the alignment information. After the analysis finishes,
these files are saved in mini analysis and the original analysis results are
removed after archiving.

Since these files are not compressed, they consume more disk space, which is
limited. Hence, a potential improvement could be to generate a single BAM file
per lane. A BAM file would contain the sample, library and the platform
information in addition to individual reads and their corresponding mapping
information. Since a BAM file is compressed, this would imply reduction in the
disk space usage. Thus, through this conversion, we will have 8 BAM files, one
for each lane, instead of a larger number of files as we have right now. In
addition, BAM files are simpler to use for further downstream analysis such as
identifying the duplicates.

Examples

Usage Scenario

The following commands describe GERALD_Driver.rb to start the analysis.

Examples :

(i) ruby GERALD_Driver.rb 100319_P21_0431_AFC2003B 4 
This starts analysis of lane 4 of flowcell 100319_P21_0431_AFC2003B. Reference
paths, number of cycles is automatically obtained from LIMS.

(ii) ruby GERALD_Driver.rb 100319_P21_0431_AFC2003B 5 100 paired
/stornext/snfs5/next-gen/Illumina/genomes/p/phix/squash 
This starts the analysis of lane 5 of the flowcell, whily specifying the number
of cycles (100), type of run (paired) and reference path.

(iii) ruby GERALD_Driver.rb 100319_P21_0431_AFC2003B 46 
This starts the analysis for lanes 4 and 6, as long as both these lanes have the
same reference path listed in LIMS.

(iv) ruby GERALD_Driver.rb 100319_P21_0431_AFC2003B 567 100 paired
/stornext/snfs5/next-gen/Illumina/genomes/p/phix/squash 
This starts the analysis for the lanes 5, 6 and 7 with the phix reference.

Sample GERALD configuration file

Configuration file for a typical fragment sequencing run from GA2 sequencer for
CASAVA 1.6 looks like :

ELAND_GENOME /data/slx/references/h/homosapiens_hg18_build_36.1/squash
1:ANALYSIS eland_extended
2345678:ANALYSIS none
USE_BASES Y95
FLOW_CELL v4
ELAND_SET_SIZE 40
WEB_DIR_ROOT file:///data/slx
EMAIL_SERVER mail.hgsc.bcm.tmc.edu
EMAIL_DOMAIN bcm.edu
EMAIL_LIST niravs@bcm.edu
POST_RUN_COMMAND /data/slx/goats/hgsc_slx/bin/post_run_cmd.sh

Configuration file for a paired end sequencing run from GA2 sequencers for
CASAVA version 1.6 looks like

ELAND_GENOME /data/slx/references/b/bacterial-nt/squash
67:ANALYSIS eland_pair
123458:ANALYSIS none
USE_BASES Y95
FLOW_CELL v4
WEB_DIR_ROOT file:///data/slx
EMAIL_SERVER mail.hgsc.bcm.tmc.edu
EMAIL_DOMAIN bcm.edu
EMAIL_LIST niravs@bcm.edu
POST_RUN_COMMAND /data/slx/goats/hgsc_slx/bin/post_run_cmd.sh
In the above example, ELAND_SET_SIZE defaults to 40.

Configuration file for a paired end sequencing run from HiSeq sequencers for
CASAVA version 1.6

ELAND_GENOME /data/slx/references/b/bacterial-nt/squash
67:ANALYSIS eland_pair
123458:ANALYSIS none
USE_BASES Y95
FLOW_CELL v4
ELAND_SET_SIZE 4
WEB_DIR_ROOT file:///data/slx
EMAIL_SERVER mail.hgsc.bcm.tmc.edu
EMAIL_DOMAIN bcm.edu
EMAIL_LIST niravs@bcm.edu
POST_RUN_COMMAND /data/slx/goats/hgsc_slx/bin/post_run_cmd.sh

In this example, ELAND_SET_SIZE must be specified, recommended value is 4.
