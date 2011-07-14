import net.sf.samtools.SAMRecord;
import java.util.Arrays;
import java.io.*;

/**
 * Class to calculate and plot the average base quality per base position
 * @author Nirav Shah niravs@bcm.edu
 */
public class QualPerPosnCalculator extends MetricsCalculator
{
  private double meanQualRead1[] = null; // Mean base quality per read1
  private double meanQualRead2[] = null; // Mean base quality per read2
  private double numRead1[]      = null; // Number of read 1s
  private double numRead2[]      = null; // Number of read2s
  private int readLen              = 0;  // Read length
  private int maxLen               = 0;  // Max read length seen so far
  private final int QUAL_ADDEND    = 33; // Addition to phred base qualities
	  
  // Create an inner class to determine range of plot
  private class ScaleRange
  {
    double minValue = 0;
    double maxValue = 0;
  }
  
  /**
   * Default class constructor
   */
  public QualPerPosnCalculator()
  {
    super();
    meanQualRead1 = new double[maxLen];
    meanQualRead2 = new double[maxLen];
    numRead1      = new double[maxLen];
    numRead2      = new double[maxLen];
  }

  /* (non-Javadoc)
   * @see MetricsCalculator#processRead(net.sf.samtools.SAMRecord)
   */
  @Override
  void processRead(SAMRecord nextRead) throws Exception
  {
    String baseQualString = nextRead.getBaseQualityString();
    readLen = baseQualString.length();
	 
    if(readLen > maxLen)
    {
      maxLen = readLen;
      meanQualRead1 = Arrays.copyOf(meanQualRead1, readLen);
      meanQualRead2 = Arrays.copyOf(meanQualRead2, readLen);
      numRead1      = Arrays.copyOf(numRead1, readLen);
      numRead2      = Arrays.copyOf(numRead2, readLen);
    }
   // Read 1 or fragment
   if(!nextRead.getReadPairedFlag() || 
     (nextRead.getReadPairedFlag() && nextRead.getFirstOfPairFlag()))
    {
      calculateBaseQuality(1, baseQualString, nextRead.getReadNegativeStrandFlag());
    }
    else
    {
      if(nextRead.getReadPairedFlag() && nextRead.getSecondOfPairFlag())
      {
        calculateBaseQuality(2, baseQualString, nextRead.getReadNegativeStrandFlag());
      }
    }		
  }
  
  /* (non-Javadoc)
   * @see MetricsCalculator#buildResultMetrics()
   */
  @Override
  void buildResultMetrics()
  {
    resultMetric = null;
  }

  /* (non-Javadoc)
   * @see MetricsCalculator#calculateResult()
   */
  @Override
  void calculateResult()
  {
    Plot p = null;
	    
    double xPosn[] = new double[readLen];
	    
    for(int i = 0; i < readLen; i++)
    {
      xPosn[i] = i + 1;
    }
    try
    {
      ScaleRange yRange = findMinMaxRange();
      logQualScoreDistribution();
	      
      if(meanQualRead1 != null && meanQualRead1.length > 0)
      {
         if(meanQualRead2 != null && meanQualRead2.length > 0)
         {
           p = new Plot("BaseQualPerPosition.png", "Avg. Base Quality Per Position", 
               "Base Position", "Avg. Base Quality - Phred Scale", "Read 1", "Read 2", xPosn, meanQualRead1, 
               meanQualRead2);
         }
         else
         {
           p = new Plot("BaseQualPerPosition.png", "Avg. Base Quality Per Position",
	                    "Base Position", "Avg. Quality", "Read 1", xPosn, meanQualRead1);
         }
       }
       if(p != null)
       {
         p.setYScale(yRange.minValue, yRange.maxValue + 10);
         p.plotGraph();
       }
    }
    catch(Exception e) 
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
    }
  }

  /**
   * Calculates average base quality per position
   * @param qualArray
   * @param baseQual
   * @param totalReads
   * @param reverseStrand - whether the read is on reverse strand
   */
  private void calculateBaseQuality(int readType, String baseQual, boolean reverseStrand)
  {
    int qual;
    double qualArray[] = null;
    double numReads[]  = null;
    int baseQualLength = baseQual.length();
    int pos;
	    
    if(readType == 1)
    {
      qualArray = meanQualRead1;
      numReads  = numRead1;
    }
    else
    {
      qualArray = meanQualRead2;
      numReads  = numRead2;
    }
    for(int i = 0; i < baseQualLength; i++)
    {
      /**
       * If the read is on the reverse strand, the sequence of base qualities 
       * will be reversed in the BAM. Hence, while calculating the average, we 
       * reverse the positions once again.
       */
      if(reverseStrand)
      {
        pos = baseQualLength -1 -i;
      }
      else
      {
        pos = i;
      }
      qual = baseQual.charAt(i) - QUAL_ADDEND;
      qualArray[pos] = (qualArray[pos] * (numReads[pos]) + qual) / 
                       (1.0 * (numReads[pos] + 1));
      numReads[pos] = numReads[pos] + 1;
    }
  }

  /**
   * Set proper scale for Y-axis
   * @return ScaleRange object
   */
  private ScaleRange findMinMaxRange()
  {
    double minYValue = 0;
    double maxYValue = 0;
	    
    for(int i = 0; i < meanQualRead1.length; i++)
    {
      if(minYValue > meanQualRead1[i])
        minYValue = meanQualRead1[i];
      if(maxYValue < meanQualRead1[i])
        maxYValue = meanQualRead1[i];
    }
    
    if(meanQualRead2 != null && meanQualRead2.length > 0)
    {
      for(int i = 0; i < meanQualRead1.length; i++)
      {
    	if(minYValue > meanQualRead1[i])
    	  minYValue = meanQualRead1[i];
    	if(maxYValue < meanQualRead1[i])
    	  maxYValue = meanQualRead1[i];
      }
    }
    
    if(minYValue > 0)
      minYValue = 0;
    ScaleRange yRange = new ScaleRange();
    yRange.minValue = minYValue;
    yRange.maxValue = maxYValue;
    return yRange;
  }
  
  /**
   * Helper method to log avg. base quality score distribution
   * @throws IOException
   */
  private void logQualScoreDistribution() throws IOException
  {
    String logFileName = "AvgQualScoreDist.csv";
    BufferedWriter writer = new BufferedWriter(new FileWriter(logFileName));
    StringBuffer record = null;
    String delimiter = ",";
    
    int maxLen = meanQualRead1.length;
    
    if(meanQualRead2 != null && maxLen < meanQualRead2.length)
    {
      maxLen = meanQualRead2.length;
    }
    for(int i = 0; i < maxLen; i++)
    {
      record = new StringBuffer((i + 1) + delimiter);
      
      if(meanQualRead1 != null && meanQualRead1.length > i)
      {
        record.append(meanQualRead1[i] + delimiter);
      }
      if(meanQualRead2 != null && meanQualRead2.length > i)
      {
        record.append(meanQualRead2[i] + delimiter);
      }
      writer.append(record.toString());
      writer.newLine();
      record = null;
    }
    writer.close();
  }
}
