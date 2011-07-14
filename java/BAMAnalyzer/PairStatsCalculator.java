import net.sf.samtools.SAMRecord;
import org.w3c.dom.*;

/**
 * Class to calculate pair-wise statistics information
 */

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class PairStatsCalculator extends MetricsCalculator
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
	super();
  }
  
  /**
   * Calculate pair statistics for the current read
   * @param record
   */
  @Override
  public void processRead(SAMRecord record) throws Exception
  {
    if(record.getReadPairedFlag() && !record.getFirstOfPairFlag())
    {
      // Since this is a second read in a pair, increment totalPairs
      totalPairs++;
    }
    // Don't consider fragment reads, first reads in a pair
    if(!record.getReadPairedFlag() || record.getFirstOfPairFlag())
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
      
      if(record.getMateReferenceName().equals(record.getReferenceName()))
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
  public void calculateResult()
  {
    if(totalPairs > 0)
    {
      percentMappedPairs = 1.0 * mappedPairs / totalPairs * 100.0;
      percentSameChrMappedPairs = 1.0 * mappedPairSameChr / totalPairs * 100.0;
      percentUnmappedpairs =  1.0 * unmappedPairs / totalPairs * 100.0;
      percentRead1Mapped = 1.0 * read1Mapped / totalPairs * 100.0;
      percentRead2Mapped = 1.0 * read2Mapped / totalPairs * 100.0;
    }
  }

  @Override
  public void buildResultMetrics()
  {
    // Build the result metrics object for logging
	resultMetric.setMetricName("PairMetrics");
	
	ResultMetric mappedPairMetrics = new ResultMetric();
	mappedPairMetrics.setMetricName("MappedPairs");
	mappedPairMetrics.addKeyValue("NumReads", Long.toString(mappedPairs));
	mappedPairMetrics.addKeyValue("PercentReads", Double.toString(percentMappedPairs));
	resultMetric.addResultMetric(mappedPairMetrics);
	
	ResultMetric sameChrMappedMetrics = new ResultMetric();
	sameChrMappedMetrics.setMetricName("SameChrMappedPairs");
	sameChrMappedMetrics.addKeyValue("NumReads", Long.toString(mappedPairSameChr));
	sameChrMappedMetrics.addKeyValue("PercentReads", Double.toString(percentSameChrMappedPairs));
	resultMetric.addResultMetric(sameChrMappedMetrics);
	
	ResultMetric unmappedPairMetrics = new ResultMetric();
	unmappedPairMetrics.setMetricName("UnmappedPairs");
	unmappedPairMetrics.addKeyValue("NumReads", Long.toString(unmappedPairs));
	unmappedPairMetrics.addKeyValue("PercentReads", Double.toString(percentUnmappedpairs));
	resultMetric.addResultMetric(unmappedPairMetrics);
	
	ResultMetric Read1MappedMetrics = new ResultMetric();
	Read1MappedMetrics.setMetricName("Read1Mapped");
	Read1MappedMetrics.addKeyValue("NumReads", Long.toString(read1Mapped));
	Read1MappedMetrics.addKeyValue("PercentReads", Double.toString(percentRead1Mapped));
	resultMetric.addResultMetric(Read1MappedMetrics);
	
	ResultMetric Read2MappedMetrics = new ResultMetric();
	Read2MappedMetrics.setMetricName("Read2Mapped");
	Read2MappedMetrics.addKeyValue("NumReads", Long.toString(read2Mapped));
	Read2MappedMetrics.addKeyValue("PercentReads", Double.toString(percentRead2Mapped));
	resultMetric.addResultMetric(Read2MappedMetrics);
  }
  
  @Override
  public String toString()
  {
	String newLine = "\r\n";
	
    StringBuffer resultString = new StringBuffer();
    resultString.append("Pair Statistics" + newLine + newLine);
    resultString.append("Total Read Pairs        : " + totalPairs + newLine);
    resultString.append(newLine);

    if(totalPairs > 0)
    {
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
    }
    return resultString.toString();
  }
  
  
  public Element toXML(Document doc)
  {
    Element pairInfo = doc.createElement("PairMetrics");

    if(totalPairs > 0)
    {
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
    } 
    return pairInfo;
  }
}
