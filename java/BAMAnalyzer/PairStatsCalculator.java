import net.sf.samtools.SAMRecord;

/**
 * Class to calculate pair-wise statistics information
 */

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class PairStatsCalculator
{
  private long unmappedPairs     = 0; // Pairs where both reads are unmapped
  private long read1Mapped       = 0; // Pairs with only read 1 mapped
  private long read2Mapped       = 0; // Pairs with only read 2 mapped
  private long mappedPairs       = 0; // Pairs with both ends mapped
  private long mappedPairSameChr = 0; // Pairs where both ends map to same chromosome
  private long totalPairs        = 0; // Total number of pairs
  
  /**
   * Class constructor
   */
  public PairStatsCalculator()
  {
    // For now nothing
  }
  
  /**
   * Calculate pair statistics for the current read
   * @param record
   */
  public void processRead(SAMRecord record)
  {
    // Don't consider fragment reads, first reads in a pair, or duplicate reads
    if(!record.getReadPairedFlag() || record.getFirstOfPairFlag() || record.getDuplicateReadFlag())
      return;
    
    // Since this is a second read in a pair, increment totalPairs
    totalPairs++;
    
    // If both ends are unmapped, increment unmapped pair counter
    if(record.getReadUnmappedFlag() && record.getMateUnmappedFlag())
    {
      unmappedPairs++;
    }
    else
    if(!record.getReadUnmappedFlag() && !record.getMateUnmappedFlag())
    {
      mappedPairs++;
      
      if(!record.getDuplicateReadFlag() &&
			  record.getMateReferenceName().equals(record.getReferenceName()))
      {
        mappedPairSameChr++;
      }
    }
    else
    if(!record.getReadUnmappedFlag() && record.getMateUnmappedFlag())
    {
      read2Mapped++;
    }
    else
    if(record.getReadUnmappedFlag() && !record.getMateUnmappedFlag())
    {
      read1Mapped++;
    }
  }
  
  /**
   * Public helper method to display the results
   */
  public void showResult()
  {
    if(totalPairs <= 0)
      return;
    
    System.out.println();
    System.out.println("Pair Statistics");
    System.out.println();
    System.out.println("Total Read Pairs        : " + totalPairs);
    System.out.println();
    System.out.println("Mapped Pairs            : " + mappedPairs);
    System.out.format("%% Mapped Pairs          : %.2f%%\n", 1.0 * mappedPairs / totalPairs * 100.0);
    System.out.println("Same Chr Mapped Pairs   : " + mappedPairSameChr);
    System.out.format("%% Same Chr Mapped Pairs : %.2f%%\r\n", 1.0 * mappedPairSameChr / totalPairs * 100.0);
    System.out.println("Unmapped Pairs          : " + unmappedPairs);
    System.out.format("%% Unmapped Pairs        : %.2f%%\r\n", 1.0 * unmappedPairs / totalPairs * 100.0);
    System.out.println("Mapped First Read       : " + read1Mapped);
    System.out.format("%% Mapped First Read     : %.2f%%\r\n", 1.0 * read1Mapped / totalPairs * 100.0);
    System.out.println("Mapped Second Read      : " + read2Mapped);
    System.out.format("%% Mapped Second Read    : %.2f%%\r\n", 1.0 * read2Mapped / totalPairs * 100.0);
  }
}
