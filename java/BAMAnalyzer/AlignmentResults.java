import net.sf.samtools.*;
import java.text.*;

/**
 * Class to encapsulate the alignment results and throughput metrics of a
 * sequencing event.
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class AlignmentResults 
{
  private long totalReads        = 0;  // Total reads of the specified type
  private long mappedReads       = 0;  // Number of mapped reads
  private long unmappedReads     = 0;  // Number of unmapped reads
  private long dupReads          = 0;  // Number of duplicate reads
  
  private long totalValidBases   = 0;  // Total number of bases excluding Ns
  private long totalBases        = 0;  // Total number of bases including Ns
  private long totalMappedBases  = 0;  // Number of bases for reads that map
                                       // (Partially or completely)
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
     int readLength = record.getReadLength();
     
	  // We assume that the caller will check for the type of the
    // read and invoke the function with the correct type of read.
	  totalReads++;

	  // For an unmapped read, increment the counter for unmapped read
      if(record.getReadUnmappedFlag())
        unmappedReads++;
      else
      {
			  mappedReads++;
			
        if(record.getDuplicateReadFlag())
          dupReads++;

        // Since the read is mapped, update total number of mapped bases.
        // This is used to calculate the percentage of mismatches. This is 
        // an approximate calculation since we don't look at each base to check
        // if it mapped.
        totalMappedBases += readLength;
        
        totalBases += readLength;
        totalValidBases += countValidBases(record.getReadString());
      
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
      System.out.println("Alignment Results - Read Type : " + readName);
      System.out.println();
      System.out.println("Total Reads       : " + totalReads);
      System.out.println("Unmapped Reads    : " + unmappedReads);
      System.out.println("Mapped Reads      : " + mappedReads);

      if(mappedReads > 0)
        System.out.format("%% Mapped Reads    : %.2f%% %n", (1.0 * mappedReads / totalReads * 100));
      else
        System.out.println("% Mapped Reads  : 0%");
      
      if(totalBases > 0)
        System.out.format("%% Mismatch        : %.2f%% %n", (1.0 * totalMismatches / totalMappedBases * 100.0));
      else
        System.out.println("%% Mismatch       : 100%");
      System.out.println();
      
      System.out.println("Duplicate Reads   : " + dupReads);
      if(mappedReads > 0)
        System.out.format("%% Duplicate Reads : %.2f%% %n", (1.0 * dupReads / mappedReads * 100.0));
      else
        System.out.println("% Duplicate Reads  : 0%");
      System.out.println();

      System.out.println("Exact Match Reads : " + totalExactMatches);
      if(mappedReads > 0)
        System.out.format("%% Exact Match Reads : %.2f%% %n", (1.0 * totalExactMatches / mappedReads * 100));
      else
        System.out.println("% Exact Match Reads : 0%");
      System.out.println();
      
      System.out.println("Total Bases (including Ns)       : " + totalBases);
      System.out.println("Total Valid Bases (excluding Ns) : " + totalValidBases);
      System.out.println();
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
  
  /**
   * Count the number of valid bases in a read. Valid bases are the ones without
   * Ns
   * @param baseString - readString
   * @return - Sum of valid bases
   */
  private int countValidBases(String readString)
  {
    int numValidBases = 0;
    
    readString = readString.toUpperCase();
    
    for(int i = 0; i < readString.length(); i++)
    {
      if(readString.charAt(i) != 'N')
      {
        numValidBases++;
      }
    }
    return numValidBases;
  }
}
