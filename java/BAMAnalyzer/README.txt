Project to calculate the alignment and other metrics in a SAM/BAM file.

Following metrics are calculated:

=============================
===== Alignment Metrics =====
=============================

They are reported for each read type. There are 3 read types namely, fragment, 
read1 (first read in the pair) or read2 (second read in the pair).

1) Total Reads       - Number of reads of the given type.

2) Unmapped Reads    - Number of reads of the given type that do not map.

3) Mapped Reads      - Number of reads of the given type that map.

4) % Mapped Reads    - Percentage of Mapped Reads calculated over Total Reads.

5) % Mismatch        - Percentage of mismatches (from CIGAR/MD tag) over total 
                       mapped bases.
                       totalMismatches / totalMappedBases * 100
 
6) Exact Match Reads - Number of reads without mismatches in CIGAR/MD tag.                   

7) % Exact Matches   - Percentage of reads without mismatches over mapped reads.
                       totalExactMatches / mappedReads * 100
                       
8) Duplicate Reads   - Number of duplicate reads as reported by MarkDuplicates.jar  

9) % Duplicates      - Percentage of duplicate reads over mapped reads.
                       totalDuplicateReads / mappedReads * 100
                       
10) Total Bases      - Total yield for the given read type.

11) Valid Bases      - Total yield while removing all "N"s.                     


=============================
==== Insert Size Metrics ====
=============================

12) Pairs With Both Reads   - Total Number of read pairs where both mates map on  
    On Same Chromosome        the same chromosome while ignoring duplicate reads
                              and reads that are not primary alignment reads.
                            
13) % Pairs With Both Reads - Percentage of above metric over total pairs
    On Same Chromosome        
                              sameChrMappedPrimaryPairs / totalPairs * 100
                              
In addition, for each pair orientation type (FR, RF, Tandem), the following 
metrics are reported if the number of read pairs of the given orientation is
at least 10% of the number of read pairs reported in 12).

14) Median Inert Size - Median value of the insert size for the given pair orientation.

15) Mode Insert Size  - Modal value of the insert size for the given pair orientation.
                 
16) Number of Pairs   - Total Number of read pairs where both mates map on
                        the same chromosome while ignoring duplicate reads
                        and reads that are not primary alignment reads, and
                        the pair has given orientation.
                        
17) % Pairs           - Percentage of same chromosome mapped pairs with given
                        orientation over total same chromosome mapped pairs.
                        
                        sameChrGivenOrientationPairs / sameChrMappedPrimaryPairs * 100
                        
=============================
======== Pair Metrics =======
=============================

18) Total Pairs      - Total pairs in the file.

19) Mapped Pairs     - Total pairs where both ends are mapped.

20) % Mapped Pairs   - Percentage of mapped pairs over total pairs.
                       mappedPairs / totalPairs * 100
                      
21) Same chr Pairs   - Total pairs where both ends are mapped on the same 
                       chromosome.
                      
22) % Same Chr Pairs - Percentage of Same chromosome pairs over total pairs.
                       sameChrPairs / totalPairs * 100
                       
23) Unmapped Pairs   - Total pairs where both reads are unmapped.

24) % Unmapped Pairs - Percentage of unmapped pairs over total pairs.
                       totalUnmappedPairs / totalPairs * 100
                       
25) Mapped First Reads  - Pairs where only first read is mapped. 
                         
26) % Mapped First Read - Percentage over total read pairs.
                          mappedFirstReadOnlyPairs / totalPairs * 100
                          
27) Mapped Second Reads - Pairs where only second read is mapped. 
                          
28) % Mapped Second Read - Percentage over total read pairs.
                           mappedSecondReadOnlyPairs / totalPairs * 100


===================================
==== Base Quality Per Position ====
===================================

It calculates the average base quality per read position and plots a graph.
This metric is reported only in the graph form.


Note:

The following diagram explains the meaning of different pair orientations.

(5' --F-->     <--R-- 5') ---- FR orientation

(<--R-- 5'     5' --F-->) ---- RF orientation

( 5' --F-->    5' --F-->) ---- Tandem orientation

(<--R-- 5'     <--R-- 5') ---- Tandem orientation 