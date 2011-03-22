/**
 * Class encapsulating functionality to detect for bad reads. Bad reads
 * are reads containing Ns beyond a specifid threshold.
 */

/**
 * @author Nirav Shah - niravs@bcm.edu
 *
 */
public class BadReadCount
{
  long totalRead1     = 0;    // Total reads - read1
  long totalRead2     = 0;    // Total reads - read2
  long badReadsRead1  = 0;    // Bad reads for read 1
  long badReadsRead2  = 0;    // Bad reads for read 2
  long nDistRead1[]   = null; // Distribution of bad reads for read 1
  long nDistRead2[]   = null; // Distribution of bad reads for read 2 
  private int readLen = 0;    // Read Length

  /**
   * Constructor - nothing to do for now
   */
  public BadReadCount(int readLen)
  {
    this.readLen = readLen;
    nDistRead1 = new long[readLen];
    nDistRead2 = new long[readLen];
  }

  /**
   * Show the result
   */
  public void showResult()
  {
    System.out.println("Total Reads (Read 1)   : " + totalRead1);
    System.out.println("Bad Reads (Read 1)     : " + badReadsRead1);
    
    if(totalRead1 > 0)
      System.out.format("%% Bad Reads            : %.2f %%\r\n", badReadsRead1 * 100.0 / totalRead1 );
    else
      System.out.println("%% Bad Reads           : 0");
    
    if(totalRead2 > 0)
    {
      System.out.println("Total Reads (Read 2)   : " + totalRead2);
      System.out.println("Bad Reads (Read 2)     : " + badReadsRead2);
      System.out.format("%% Bad Reads            : %.2f %%\r\n", badReadsRead2 * 100.0 / totalRead2);
    }
    createDistributionChart();
  }

  private void createDistributionChart()
  {
    String outputFile = "DistributionOfN.png";
    double xAxis[]    = new double[readLen];
    double yData[]    = new double[readLen];
    double y2Data[]   = new double[readLen];

   for(int i = 0; i < readLen; i++)
   {
     xAxis[i]  = (i + 1);
     if(totalRead1 > 0)
     {
       yData[i]  = 1.0 * nDistRead1[i] / totalRead1 * 100.0;
     }
     else
     {
       yData[i] = 0.0;
     }
     if(totalRead2 > 0)
     {
       y2Data[i] = 1.0 * nDistRead2[i] / totalRead2 * 100.0;
     }
     else
     {
       y2Data[i] = 0.0;
     }
   }

   try
   {
     Plot p = null;
     if(totalRead2 > 0)
     {
       p = new Plot(outputFile, "Distribution of N in Reads", "Start Point",
                       "Percentage of N", "Ns in Read1", "Ns in Read2", xAxis,
                       yData, y2Data);
     }
     else
     {
       p = new Plot(outputFile, "Distribution of N in Reads", "Start Point",
                    "Percentage of N", "Ns in Read1", xAxis, yData);
     }
     p.plotGraph();
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
    }
  }
}
