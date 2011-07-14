/**
 * Class to calculate mismatches in a BAM record
 */

import net.sf.samtools.*;
import java.util.*;

/**
 * @author niravs
 *
 */
public class MismatchCounter 
{
  /**
   * Method to count the number of mismatches in the given read	
   * @param samRecord - Instance of one read
   * @return - Number of mismatches
   */
  public int countMismatches(SAMRecord samRecord) throws Exception
  {
    int numMismatches = 0;
    
    if(samRecord.getReadUnmappedFlag())
    {
      throw new Exception("Error : Cannot count mapping mismatch for unmapped read");
    }
    String mdTag = (String) samRecord.getAttribute("MD");
    
    if(mdTag == null || mdTag.isEmpty())
    {
      throw new Exception("Error : MD tag is NULL / Empty");
    }
    
    numMismatches = countMismatchesInMDTag(mdTag) + countMismatchesInCIGAR(samRecord.getCigar());
    return numMismatches;
  }
  
  /**
   * Method to count the number of mismatches in the MD tag.
   * We use MD tag to count the number of mismatches and deletions.
   * @param mdTag
   * @return
   */
  private int countMismatchesInMDTag(String mdTag)
  {
    int mismatches = 0;
    
    /**
     * In the MD tag, a base (i.e. a letter character) implies either a
     * mismatch or a deletion.
     */
    for(int i = 0; i < mdTag.length(); i++)
    {
      if(mdTag.charAt(i) >= 'A' && mdTag.charAt(i) <= 'Z' ||
			 mdTag.charAt(i) >= 'a' && mdTag.charAt(i) <= 'z')
      {
        mismatches++;
      }
    }
    return mismatches;
  }
  
  /**
   * Method to count number of mismatches from the CIGAR string.
   * We count the number of insertions, padding, soft and hard clips.
   * @param cg
   * @return
   */
  private int countMismatchesInCIGAR(Cigar cigar)
  {
    int numMismatches = 0;
    
    List<CigarElement> cigars = cigar.getCigarElements();
    
    for (CigarElement cig : cigars)
    {
      if(cig.getOperator().name().equals("I") || // Insertion
         cig.getOperator().name().equals("N") || // Skipped region from reference
         cig.getOperator().name().equals("H") || // Hard-clip
         cig.getOperator().name().equals("S") || // Soft-clip
         cig.getOperator().name().equals("P"))   // Padding
      {
        numMismatches += cig.getLength();
      }
    }
    return numMismatches;
  }
}
