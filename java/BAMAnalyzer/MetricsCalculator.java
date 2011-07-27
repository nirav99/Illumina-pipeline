import net.sf.samtools.*;
import java.text.DecimalFormat;
import java.text.NumberFormat;

/**
 * Generic class representing calculation of various metrics
 * @author Nirav Shah niravs@bcm.edu
 */
abstract public class MetricsCalculator
{
  protected ResultMetric resultMetric;   // Result metric
  protected Plot p;                      // To generate plots
  private NumberFormat formatter;        // To format numbers
  
  public MetricsCalculator()
  { 
    resultMetric = new ResultMetric();
    p = null;
    formatter = new DecimalFormat("#0.00");
  }
  
  abstract void processRead(SAMRecord nextRead) throws Exception;
  abstract void calculateResult();
  abstract void buildResultMetrics();
  
  public ResultMetric getResultMetrics()
  {
    return resultMetric;
  }
  
  /**
   * Helper method to truncate doubles to 2 decimal places and return a string
   * @param d
   * @return
   */
  protected String getFormattedNumber(double d)
  {
    return formatter.format(d);
  }
}
