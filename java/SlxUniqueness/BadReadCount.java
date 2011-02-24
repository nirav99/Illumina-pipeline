/**
 * Class encapsulating functionality to detect for bad reads. Bad reads
 * are reads containing all Ns.
 */

/**
 * @author Nirav Shah - niravs@bcm.edu
 *
 */
public class BadReadCount
{
  long totalRead1    = 0; // Total reads - read1
  long totalRead2    = 0; // Total reads - read2
  long badReadsRead1 = 0; // Bad reads for read 1
  long badReadsRead2 = 0; // Bad reads for read 2
 
  /**
   * Constructor - nothing to do for now
   */
  public BadReadCount()
  {
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
  }
}
