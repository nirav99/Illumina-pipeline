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
  private double badReadThreshold = 0.15; // 15% threshold for Ns in a read to
                                          // be classified as a bad read
 
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
   * Helper method to check if given read sequence is bad, i.e. having N
   * beyond a certain threshold
   * @param readSequence - A string representing read sequence
   * @return - True if the read sequence is bad, false otherwise.
   */
/*
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
*/

  /**
   * Helper method to check if a given read sequence is bad, i.e., having
   * "N" as the value of bases exceeding the specified threshold.
   */
  private boolean isReadBad(String readSequence)
  {
    int readLen = readSequence.length();
    int maxAllowedNs =  (int) (badReadThreshold * readLen);
    int numNs = 0;

    for(int i = 0; i < readLen; i++)
    {
      if(readSequence.charAt(i) == 'N' || readSequence.charAt(i) == 'n')
      {
        numNs++;
        if(numNs >= maxAllowedNs)
          return true;
      }
    }
    return false;
  }
}
