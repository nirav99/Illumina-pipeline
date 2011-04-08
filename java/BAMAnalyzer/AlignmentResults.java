import net.sf.samtools.*;
import java.text.*;

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class AlignmentResults 
{
  private long totalReads        = 0;  // Total reads of the specified type
  private long mappedReads       = 0;  // Number of mapped reads
  private long unmappedReads     = 0;  // Number of unmapped reads
  private long dupReads          = 0;  // Number of duplicate reads
  
  private long totalMappedBases  = 0;  // Total number of mapped bases
  private long totalBases        = 0;  // Total number of bases
  private long totalMismatches   = 0;  // Total number of mismatches
  private long totalExactMatches = 0;  // Total number of reads with no mismatches
  
  private String readName = ""; // Read name - Read1 or Read2
  private MismatchCounter mCtr  = null; // To count the number of mismatches
  
  /**
   * Class constructor.
   * @param readName - Name of the read
   */
  public AlignmentResults(String readName, MismatchCounter mCtr)
  {
    this.readName = readName;
    this.mCtr = mCtr;
  }
  
  /**
   * Method to examine the read and update the counters
   * @param record
   */
  public void processRead(SAMRecord record) throws Exception
  {
     int numMismatches = 0; // Number of mismatches in current read
     
	 // We assume that the caller will check for the type of the
     // read and invoke the function with the correct type of read.
	  totalReads++;

	  // For an unmapped read, increment the counter for unmapped read
	  if(record.getReadUnmappedFlag())
	    unmappedReads++;
	  else
	  {
      if(record.getDuplicateReadFlag())
        dupReads++;
      
      // For mapped read, increment the corresponding counter.
      // Count the number of mapped bases as number of mapped read lengths.
      // This could be improved by adding ONLY the number of bases that
      // actually map.
      mappedReads++;
      totalMappedBases += record.getReadLength();
      numMismatches = mCtr.countMismatches(record);
      
      if(numMismatches == 0)
      {
        totalExactMatches++;
      }
      totalMismatches += numMismatches;
	  }
  }
  
  /**
   * Display alignment results
   */
  public void showAlignmentResults()
  {
    if(totalReads > 0)
    {
      System.out.println();
      System.out.println("Read Type : " + readName);
      System.out.println();
      System.out.println("Total Reads       : " + totalReads);
      System.out.println("Mapped Reads      : " + mappedReads);
      System.out.println("Unmapped Reads    : " + unmappedReads);
      
      if(mappedReads > 0)
        System.out.format("%% Mapped Reads    : %.2f%% %n", (1.0 * mappedReads / totalReads * 100));
      else
        System.out.println("% Mapped Reads  : 0%");
      System.out.println();
      
      System.out.println("Duplicate Reads   : " + dupReads);
      if(mappedReads > 0)
        System.out.format("%% Duplicate Reads : %.2f%% %n", (1.0 * dupReads / mappedReads * 100.0));
      else
        System.out.println("% Duplicate Reads  : 0%");
      
      System.out.println();

      System.out.println("Exact Match Reads : " + totalExactMatches);
      if(mappedReads > 0)
      {
        System.out.format("%% Exact Match Reads : %.2f%% %n", (1.0 * totalExactMatches / mappedReads * 100));
      }
      else
      {
        System.out.println("% Exact Match Reads : 0%");
      }
      System.out.println();
      
      System.out.println("Total Mapped Bases  : " + totalMappedBases);
      System.out.println("Total Mismatches    : " + totalMismatches);
      if(totalMappedBases > 0)
        System.out.format("Mismatch Percentage : %.2f%% %n", (1.0 * totalMismatches / totalMappedBases * 100.0));
      else
        System.out.println("Mismatch Percentage : 100%");
    }
  }  

  /**
   * Private method to format doubles to integral format
   * @param double to be shown in integer format
   * @return Formatted string equivalent of the double
   */
  private String formatNumber(double d)
  {
    DecimalFormat df = new DecimalFormat();
    StringBuffer output = new StringBuffer();
    output = df.format(d, output, new FieldPosition((NumberFormat.INTEGER_FIELD)));
    return output.toString();
  }
  
  /**
   * Private overloaded helper method to format long
   * @param l - Long type to be shows as a string
   * @return Formatted string equivalent of input
   */
  private String formatNumber(long l)
  {
	  return formatNumber(l * 1.0); 
  }
}
