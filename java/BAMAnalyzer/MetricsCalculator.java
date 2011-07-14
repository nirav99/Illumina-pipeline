import net.sf.samtools.*;

/**
 * Generic class representing calculation of various metrics
 * @author Nirav Shah niravs@bcm.edu
 */
abstract public class MetricsCalculator
{
  protected ResultMetric resultMetric;   // Result metric
  
  public MetricsCalculator()
  { 
    resultMetric = new ResultMetric();
  }
  
  abstract void processRead(SAMRecord nextRead) throws Exception;
  abstract void calculateResult();
  abstract void buildResultMetrics();
  
  public ResultMetric getResultMetrics()
  {
    return resultMetric;
  }
}
