import net.sf.picard.sam.SamPairUtil.PairOrientation;
import net.sf.samtools.*;
import net.sf.picard.sam.*;

/**
 * Class to encapsulate calculating insert size distributions
 * @author Nirav Shah niravs@bcm.edu
 */
public class InsertSizeCalculator extends MetricsCalculator
{
  // Metrics for read pairs with specified orientation
  private InsertSizeStats frInsertSize;
  private InsertSizeStats rfInsertSize;
  private InsertSizeStats tandemInsertSize;
  
  private int totalPairs            = 0; // Total read pairs
  private double percentReadPairs   = 0;
  private int totalMappedPairs      = 0; // Pairs where both reads are mapped
  
  private ResultMetric frMetric     = null;
  private ResultMetric rfMetric     = null;  
  private ResultMetric tandemMetric = null;
  
  /**
   * Class constructor - default initialization
   */
  public InsertSizeCalculator()
  {
    frInsertSize = new InsertSizeStats(PairOrientation.FR);
    rfInsertSize = new InsertSizeStats(PairOrientation.RF);
    tandemInsertSize = new InsertSizeStats(PairOrientation.TANDEM);
  }
  
  /* 
   * Process the next read
   */
  @Override
  public void processRead(SAMRecord nextRead) throws Exception
  {
    // On encountering a paired read for the second read, increment
    // total number of pairs
    if (nextRead.getReadPairedFlag() && !nextRead.getFirstOfPairFlag())
    {
      totalPairs++;
    }
    if (!nextRead.getReadPairedFlag() || nextRead.getReadUnmappedFlag()
        || nextRead.getMateUnmappedFlag()
        || nextRead.getFirstOfPairFlag()
        || nextRead.getNotPrimaryAlignmentFlag()
        || nextRead.getDuplicateReadFlag()
        || // record.getInferredInsertSize() == 0 ||
        !nextRead.getMateReferenceName().equals(nextRead.getReferenceName()))
        return;

   totalMappedPairs++;

   int insertSize = Math.abs(nextRead.getInferredInsertSize());
   PairOrientation orientation = SamPairUtil.getPairOrientation(nextRead);

   if(orientation == PairOrientation.FR)
     frInsertSize.addInsertSize(insertSize);
   else 
   if(orientation == PairOrientation.RF)
     rfInsertSize.addInsertSize(insertSize);
   else
     tandemInsertSize.addInsertSize(insertSize);
  }

  /**
   * Compute insert sizes for each orientation types
   */
  @Override
  public void calculateResult()
  {
    if(totalMappedPairs > 0)
    {
      frInsertSize.finishedAllReads();
      rfInsertSize.finishedAllReads();
      tandemInsertSize.finishedAllReads();
    }
    
    if(frInsertSize.getTotalPairs() > totalMappedPairs * 0.1)
    {
      try
      {
        frMetric = buildResultMetricHelper(frInsertSize);
        frInsertSize.logDistribution();
      }
      catch(Exception e)
      {
        System.err.println(e.getMessage());
        e.printStackTrace();
      }
    }
    if(rfInsertSize.getTotalPairs() > totalMappedPairs * 0.1)
    {
      try
      {
        rfMetric = buildResultMetricHelper(rfInsertSize);
        rfInsertSize.logDistribution();
      }
      catch(Exception e)
      {
        System.err.println(e.getMessage());
        e.printStackTrace();
      }
    }
    if(tandemInsertSize.getTotalPairs() > totalMappedPairs * 0.1)
    {
      try
      {
        tandemMetric = buildResultMetricHelper(tandemInsertSize);
        tandemInsertSize.logDistribution();
      }
      catch(Exception e)
      {
        System.err.println(e.getMessage());
        e.printStackTrace();
      }
    }
  }
  
  /* 
   * Build the result object
   */
  @Override
  public void buildResultMetrics()
  {
    if(totalPairs < 0 || totalMappedPairs <= 0)
      resultMetric = null;
    else
    {
      resultMetric = new ResultMetric();
      resultMetric.setMetricName("InsertSizeMetrics");

      if(frMetric != null)
        resultMetric.addResultMetric(frMetric);
      if(rfMetric != null)
        resultMetric.addResultMetric(rfMetric);
      if(tandemMetric != null)
        resultMetric.addResultMetric(tandemMetric);
    }
  }
  
  /**
   * Helper method to build the result object for insert size calculations
   * for a specified orientation.
   * @param stats
   * @return
   */
  private ResultMetric buildResultMetricHelper(InsertSizeStats stats)
  {
    ResultMetric metric = new ResultMetric();
    metric.setMetricName("InsertSizeResults");
    metric.addKeyValue("PairOrientation", stats.getPairOrientation().toString());
    metric.addKeyValue("TotalPairs", Integer.toString(stats.getTotalPairs()));
    double percentPairs = 1.0 * stats.getTotalPairs() / totalMappedPairs * 100.0;
    metric.addKeyValue("PercentPairs", getFormattedNumber(percentPairs));
    metric.addKeyValue("MedianInsertSize", Integer.toString(stats.getMedianInsertSize()));
    metric.addKeyValue("ModeInsertSize", Integer.toString(stats.getModeInsertSize()));
    return metric;
  }
}
