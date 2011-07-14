import net.sf.samtools.SAMRecord;

/**
 * Different read types
 */
enum ReadType
{
  READ1,    // First read in a paired read
  READ2,    // Second read in a paired read
  FRAGMENT  // Unpaire reads only
}
/**
 * Class to calculate alignment metrics
 * @author Nirav Shah niravs@bcm.edu
 */
public class AlignmentCalculator extends MetricsCalculator
{
  private ReadType readType;           // Type of read to consider
  private long totalReads        = 0;  // Total reads of the specified type
  private long mappedReads       = 0;  // Number of mapped reads
  private long unmappedReads     = 0;  // Number of unmapped reads
  private long dupReads          = 0;  // Number of duplicate reads
  
  private long totalValidBases   = 0;  // Total number of bases excluding Ns
  private long totalBases        = 0;  // Total number of bases including Ns
  private long totalMappedBases  = 0;  // Number of bases for reads that map
                                       // (Partially or completely)
  private long totalMismatches   = 0;  // Total number of mismatches
  private long totalExactMatches = 0;  // Total number of reads with no mismatches
  
  private double percentMapped     = 0;  // Percent of mapped reads
  private double percentMismatch   = 0;  // Mismatch percentage (Error percentage)
  private double percentDup        = 0;  // Percentage of duplicate reads
  private double percentExactMatch = 0; // Percentage of matching reads with no variation
  
  private MismatchCounter mCtr  = null; // To count the number of mismatches
  
  /**
   * Class constructor. Collect metrics only for the specified read type
   * @param rType
   */
  public AlignmentCalculator(ReadType rType)
  {
	super();
    this.readType = rType;
    mCtr = new MismatchCounter();
  }
  

  /**
   * Method to process the next read
   */
  @Override
  void processRead(SAMRecord nextRead) throws Exception
  {
    if((readType == ReadType.FRAGMENT && !nextRead.getReadPairedFlag()) ||
       (readType == ReadType.READ1 && nextRead.getReadPairedFlag() && nextRead.getFirstOfPairFlag()) ||
       (readType == ReadType.READ2 && nextRead.getReadPairedFlag() && nextRead.getSecondOfPairFlag()))
    {
      computeAlignmentMetrics(nextRead);
    }
  }
  
  /**
   * Calculate the results.
   */
  @Override
  void calculateResult()
  {
    if(totalReads > 0)
    {
      percentMapped = 1.0 * mappedReads / totalReads * 100;
	      
      if(mappedReads > 0)
      {
        percentDup = 1.0 * dupReads / mappedReads * 100.0;
        percentExactMatch = 1.0 * totalExactMatches / mappedReads * 100;
      }
      else
      {
        percentDup = 0;
        percentExactMatch = 0;
      }
	      
      if(totalMappedBases > 0)
        percentMismatch = 1.0 * totalMismatches / totalMappedBases * 100.0;
      else
        percentMismatch = 100;
    }
  }

  /* (non-Javadoc)
   * Build the result metrics object for displaying the results.
   */
  @Override
  void buildResultMetrics()
  {
    if(totalReads <= 0)
    {
      resultMetric = null;
      return;
    }
    resultMetric.setMetricName("AlignmentResults");
    resultMetric.addKeyValue("ReadType", readType.toString());
    
    ResultMetric readInfo = new ResultMetric();
    readInfo.setMetricName("ReadInfo");
    readInfo.addKeyValue("TotalReads", Long.toString(totalReads));
    readInfo.addKeyValue("MappedReads", Long.toString(mappedReads));
    
    readInfo.addKeyValue("UnmappedReads", Long.toString(unmappedReads));
    readInfo.addKeyValue("PercentMapped", Double.toString(percentMapped));
    readInfo.addKeyValue("PercentMismatch", Double.toString(percentMismatch));
    readInfo.addKeyValue("PercentExactMatch", Double.toString(percentExactMatch));
    readInfo.addKeyValue("PercentDuplicate", Double.toString(percentDup));
    
    ResultMetric yieldInfo = new ResultMetric();
    yieldInfo.setMetricName("TotalYield");
    yieldInfo.addKeyValue("TotalBases", Long.toString(totalBases));
    yieldInfo.addKeyValue("ValidBases", Long.toString(totalValidBases));
    
    resultMetric.addResultMetric(readInfo);
    resultMetric.addResultMetric(yieldInfo);
  }
  
  /**
   * Private helper method to calculate alignment metrics for the given read
   * @param nextRead
   * @throws Exception
   */
  private void computeAlignmentMetrics(SAMRecord nextRead) throws Exception
  {
	int numMismatches = 0; // Number of mismatches in current read
	int readLength = nextRead.getReadLength();
	
    totalReads++;
    totalBases += readLength;
    totalValidBases += countValidBases(nextRead.getReadString());
    
    if(nextRead.getReadUnmappedFlag())
      unmappedReads++;
    else
    {
      mappedReads++;
      
      if(nextRead.getDuplicateReadFlag())
        dupReads++;
      
      // Since the read is mapped, update total number of mapped bases.
      // This is used to calculate the percentage of mismatches. This is 
      // an approximate calculation since we don't look at each base to check
      // if it mapped.
      totalMappedBases += readLength;
      
      numMismatches = mCtr.countMismatches(nextRead);
    
      if(numMismatches == 0)
      {
        totalExactMatches++;
      }
      totalMismatches += numMismatches;
    }
  }
  
  /**
   * Count the number of valid bases in a read. Valid bases are the ones without Ns
   * @param baseString - readString
   * @return - Sum of valid bases
   */
  private int countValidBases(String readString)
  {
    int numValidBases = 0;
    readString = readString.toUpperCase();
    
    for(int i = 0; i < readString.length(); i++)
    {
      if(readString.charAt(i) != 'N')
      {
        numValidBases++;
      }
    }
    return numValidBases;
  }
}
