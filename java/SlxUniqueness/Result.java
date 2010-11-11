/**
 * Class encapsulating uniqueness result
 */

/**
 * @author niravs
 *
 */
public class Result
{
  public long totalReads   = 0; // Total reads
  public long uniqueReads  = 0; // Unique reads
  public long badReads     = 0; // Bad reads - reads that are all "N"

  public String toString()
  {
    return "Total Reads : " + String.valueOf(totalReads) + " Unique Reads : " + 
    String.valueOf(uniqueReads) + " Bad Reads : " + String.valueOf(badReads);
  }
}
