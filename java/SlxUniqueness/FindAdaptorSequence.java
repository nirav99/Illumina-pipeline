/**
 * This class calculates the number of occurrences of adaptor sequences
 * in the sequenced reads.
 */

/**
 * @author niravs
 *
 */
public class FindAdaptorSequence
{
//  private Vector<String> adaptorSequences = null;  // Store adaptor sequences
  private AdaptorCount adaptorCount = null;        // To count adaptor sequences
  private String adaptorSequences[] = null;        // Remember adaptor sequences
  
  /**
   * Class constructor
   * @param adaptorFile - File name containing adaptor sequences
   * @throws Exception
   */
  public FindAdaptorSequence(int readLength) throws Exception
  {
    adaptorSequences = new String[1];
    adaptorSequences[0] = "GATCGGAA";
    
    adaptorCount = new AdaptorCount(readLength);
  }
  
  /**
   * Check if the specified read matches the adaptor string
   * @param readSequence - Read sequence
   * @param readType - 1 or 2 for read 1 or read 2
   */
  public void checkRead(String readSequence, int readType)
  {
    if(readType == 1)
    {
      adaptorCount.totalRead1++;
      
      if(true == matchFound(readSequence))
      {
        adaptorCount.adaptorRead1++;
      }
    }
    else
    if(readType == 2)
    {
      adaptorCount.totalRead2++;
      
      if(true == matchFound(readSequence))
      {
        adaptorCount.adaptorRead2++;
      }
    }
  }
  
  /**
   * Return the adaptor count object
   * @return
   */
  public AdaptorCount getAdaptorCount()
  {
    return adaptorCount;
  }
  
  /**
   * Helper method to check if given read sequence contains at least one
   * adaptor sequence
   * @param readSequence - A string representing read sequence
   * @return - True if prefix of read sequence contains adaptor sequence,
   * false otherwise
   */
  private boolean matchFound(String readSequence)
  {
    boolean result = false;
    int startPoint = -1;
    
    for(int i = 0; i < adaptorSequences.length && result == false; i++)
    {
      startPoint = readSequence.indexOf(adaptorSequences[i]);

      if(startPoint >= 0 && startPoint < readSequence.length())
      {
        result = true;

        try
        {
          adaptorCount.addStartPoint(startPoint);
        }
        catch(Exception e)
        {
          System.err.println(e.getMessage());
          e.printStackTrace();
        }
      }
    }
    return result;
  }
}
