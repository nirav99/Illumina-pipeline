import net.sf.samtools.SAMRecord;
import org.w3c.dom.*;

/**
 * Class to calculate pair-wise statistics information
 */

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class PairStatsCalculator implements MetricsCalculator
{
  private long unmappedPairs     = 0; // Pairs where both reads are unmapped
  private long read1Mapped       = 0; // Pairs with only read 1 mapped
  private long read2Mapped       = 0; // Pairs with only read 2 mapped
  private long mappedPairs       = 0; // Pairs with both ends mapped
  private long mappedPairSameChr = 0; // Pairs where both ends map to same chromosome
  private long totalPairs        = 0; // Total number of pairs
  
  private double percentMappedPairs        = 0; // Percentage of mapped pairs
  private double percentSameChrMappedPairs = 0; 
  private double percentUnmappedpairs      = 0;
  private double percentRead1Mapped        = 0;
  private double percentRead2Mapped        = 0;
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
  @Override
  public void processRead(SAMRecord record)
  {
    if(record.getReadPairedFlag() && !record.getFirstOfPairFlag())
    {
      // Since this is a second read in a pair, increment totalPairs
      totalPairs++;
    }
    // Don't consider fragment reads, first reads in a pair, or duplicate reads
    if(!record.getReadPairedFlag() || record.getFirstOfPairFlag() || record.getDuplicateReadFlag())
      return;
    
    // If both ends are unmapped, increment unmapped pair counter
    if(record.getReadUnmappedFlag() && record.getMateUnmappedFlag())
    {
      unmappedPairs++;
    }
    else
    if(!record.getReadUnmappedFlag() && !record.getMateUnmappedFlag())
    {
      // If both ends are mapped, increment mapped pair counter
      mappedPairs++;
      
      if(!record.getDuplicateReadFlag() &&
			  record.getMateReferenceName().equals(record.getReferenceName()))
      {
        // If both reads map on same chromosome, increment mapped pair same chr
        // counter
        mappedPairSameChr++;
      }
    }
    else
    if(!record.getReadUnmappedFlag() && record.getMateUnmappedFlag())
    {
      // If only read2 is mapped and read1 is not mapped, increment read2Mapped
      read2Mapped++;
    }
    else
    if(record.getReadUnmappedFlag() && !record.getMateUnmappedFlag())
    {
      // If only read1 is mapped and read2 is not mapped, increment read1Mapped
      read1Mapped++;
    }
  }
  
  /**
   * Public helper method to display the results
   */
  @Override
  public void showResult()
  {
    if(totalPairs <= 0)
      return;
    
    percentMappedPairs = 1.0 * mappedPairs / totalPairs * 100.0;
    percentSameChrMappedPairs = 1.0 * mappedPairSameChr / totalPairs * 100.0;
    percentUnmappedpairs =  1.0 * unmappedPairs / totalPairs * 100.0;
    percentRead1Mapped = 1.0 * read1Mapped / totalPairs * 100.0;
    percentRead2Mapped = 1.0 * read2Mapped / totalPairs * 100.0;
 
    System.out.println(toString());
/*
    System.out.println();
    System.out.println("Pair Statistics");
    System.out.println();
    System.out.println("Total Read Pairs        : " + totalPairs);
    System.out.println();
    System.out.println("Mapped Pairs            : " + mappedPairs);
    System.out.format("%% Mapped Pairs          : %.2f%%\n", percentMappedPairs);
    System.out.println("Same Chr Mapped Pairs   : " + mappedPairSameChr);
    System.out.format("%% Same Chr Mapped Pairs : %.2f%%\r\n", percentSameChrMappedPairs);
    System.out.println("Unmapped Pairs          : " + unmappedPairs);
    System.out.format("%% Unmapped Pairs        : %.2f%%\r\n", percentUnmappedpairs);
    System.out.println("Mapped First Read       : " + read1Mapped);
    System.out.format("%% Mapped First Read     : %.2f%%\r\n", percentRead1Mapped);
    System.out.println("Mapped Second Read      : " + read2Mapped);
    System.out.format("%% Mapped Second Read    : %.2f%%\r\n", percentRead2Mapped);
 */
  }

  @Override
  public String toString()
  {
	String newLine = "\r\n";
	
    StringBuffer resultString = new StringBuffer();
    resultString.append("Pair Statistics" + newLine + newLine);
    resultString.append("Total Read Pairs        : " + totalPairs + newLine);
    resultString.append(newLine);
    resultString.append("Mapped Pairs            : " + mappedPairs + newLine);
    resultString.append("% Mapped Pairs          : " + String.format("%.2f", percentMappedPairs) + "%" + newLine);
    resultString.append("Same Chr Mapped Pairs   : " + mappedPairSameChr + newLine);
    resultString.append("% Same Chr Mapped Pairs : " + String.format("%.2f", percentSameChrMappedPairs) + "%" + newLine);
    resultString.append("Unmapped Pairs          : " + unmappedPairs + newLine);
    resultString.append("% Unmapped Pairs        : " + String.format("%.2f", percentUnmappedpairs) + "%" + newLine);
    resultString.append("Mapped First Read       : " + read1Mapped + newLine);
    resultString.append("% Mapped First Read     : " + String.format("%.2f", percentRead1Mapped) + "%" + newLine);
    resultString.append("Mapped Second Read      : " + read2Mapped + newLine);
    resultString.append("% Mapped Second Read    : " + String.format("%.2f", percentRead2Mapped) + "%" + newLine);
    return resultString.toString();
  }
  
  @Override
  public Element toXML(Document doc)
  {
    Element pairInfo = doc.createElement("PairMetrics");
    Element mappedPairElem = doc.createElement("MappedPairs");
    mappedPairElem.setAttribute("NumReads", String.valueOf(mappedPairs));
    mappedPairElem.setAttribute("PercentReads", String.valueOf(percentMappedPairs));
    pairInfo.appendChild(mappedPairElem);
    
    Element sameChrMappedPairsElem = doc.createElement("SameChrMappedPairs");
    sameChrMappedPairsElem.setAttribute("NumReads", String.valueOf(mappedPairSameChr));
    sameChrMappedPairsElem.setAttribute("PercentReads", String.valueOf(percentSameChrMappedPairs));
    pairInfo.appendChild(sameChrMappedPairsElem);

    Element unmappedPairsElem = doc.createElement("UnmappedPairs");
    unmappedPairsElem.setAttribute("NumReads", String.valueOf(unmappedPairs));
    unmappedPairsElem.setAttribute("PercentReads", String.valueOf(percentUnmappedpairs));
    pairInfo.appendChild(unmappedPairsElem);
    
    Element read1MappedElem = doc.createElement("Read1Mapped");
    read1MappedElem.setAttribute("NumReads", String.valueOf(read1Mapped));
    read1MappedElem.setAttribute("PercentReads", String.valueOf(percentRead1Mapped));
    pairInfo.appendChild(read1MappedElem);
    
    Element read2MappedElem = doc.createElement("Read2Mapped");
    read2MappedElem.setAttribute("NumReads", String.valueOf(read2Mapped));
    read2MappedElem.setAttribute("PercentReads", String.valueOf(percentRead2Mapped));
    pairInfo.appendChild(read2MappedElem);
 
	return pairInfo;
  }
}
