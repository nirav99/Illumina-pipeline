/**
 * Class encapsulating number of sequences containing adaptor sequence
 */

/**
 * @author niravs
 *
 */
public class AdaptorCount
{
  long totalRead1   = 0; // Total reads - read1
  long totalRead2   = 0; // Total reads - read2
  long adaptorRead1 = 0; // Number of Read1 sequences having adaptor
  long adaptorRead2 = 0; // Number of Read2 sequences having adaptor
  private long startPoints[] = null; // Array to start points of reads
  private int readLen = 0;
 
  public AdaptorCount(int readLen)
  {
    this.readLen = readLen;
    // Initialize the array to remember start points
    startPoints = new long[readLen];
  }

  public void addStartPoint(int startPoint) throws Exception
  {
    if(startPoint < 0 || startPoint >= startPoints.length)
    {
      throw new Exception("Start point out of bounds");
    }
    startPoints[startPoint] = startPoints[startPoint] + 1;
  }
  
  public void showResult()
  {
    System.out.println("Total Reads (Read 1)   : " + totalRead1);
    System.out.println("Adaptor Reads (Read 1) : " + adaptorRead1);
    
    if(totalRead1 > 0)
      System.out.format("%% Reads With Adaptor   : %.2f %%\r\n", adaptorRead1 * 100.0 / totalRead1 );
    else
      System.out.println("%% Reads With Adaptor : 0");
    
    if(totalRead2 > 0)
    {
      System.out.println("Total Reads (Read 2)   : " + totalRead2);
      System.out.println("Adaptor Reads (Read 2) : " + adaptorRead2);
      System.out.format("%% Reads With Adaptor   : %.2f %%\r\n", adaptorRead2 * 100.0 / totalRead2);
    }
    createDistributionChart();
  }

  private void createDistributionChart()
  {
    String outputFile = "AdaptorReadsDistribution.png";
    double xAxis[] = new double[readLen];    
    double yAxis[] = new double[readLen];
 
    for(int i = 0; i < readLen; i++)
    {
      xAxis[i] = i + 1;
      yAxis[i] = startPoints[i];
    }
    try
    {
      Plot p = new Plot(outputFile, "Adaptor Read Distribution", "Start Point",
                        "Number of Adaptor Reads", "Distribution of Adaptor Reads", 
                      xAxis, yAxis);
      p.plotGraph();
    }
    catch(Exception e)
    {

    }
  }
}

