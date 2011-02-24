/**
 * This class calculates the number of bad reads in a sequence file, a read with
 * all N is considered a bad read.
 */

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class FindBadReads
{
  private BadReadCount bCounter = null;   // Object to remember bad reads
 
  /**
   * Class constructor
   */
  public FindBadReads()
  {
    bCounter = new BadReadCount();
  }
  
  /**
   * Check if the specified read is a bad read
   * @param readSequence - Read sequence
   * @param readType - 1 or 2 for read 1 or read 2
   */
  public void checkRead(String readSequence, int readType)
  {
    if(readType == 1)
    {
      bCounter.totalRead1++;
      
      if(true == isReadBad(readSequence))
      {
        bCounter.badReadsRead1++;
      }
    }
    else
    if(readType == 2)
    {
      bCounter.totalRead2++;
      
      if(true == isReadBad(readSequence))
      {
        bCounter.badReadsRead2++;
      }
    }
  }
 
  /**
   * Return the bad read counter count object
   * @return
   */
  public BadReadCount getBadReadCount()
  {
    return bCounter;
  }
  
  /**
   * Helper method to check if given read sequence contains at least one
   * adaptor sequence
   * @param readSequence - A string representing read sequence
   * @return - True if prefix of read sequence contains adaptor sequence,
   * false otherwise
   */
  private boolean isReadBad(String readSequence)
  {
    boolean result = true;
    
    for(int i = 0; i < readSequence.length() && result == true; i++)
    {
      if(readSequence.charAt(i) != 'N' && readSequence.charAt(i) != 'n')
        result = false;
    }
    return result;
  }
}
