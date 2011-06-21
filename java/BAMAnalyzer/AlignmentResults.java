import net.sf.samtools.*;
import java.text.*;
import org.w3c.dom.*;

/**
 * Class to encapsulate the alignment results and throughput metrics of a sequencing event.
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
  
  private double percentMapped     = 0;  // Percent of mapped reads
  private double percentMismatch   = 0;  // Mismatch percentage (Error percentage)
  private double percentDup        = 0;  // Percentage of duplicate reads
  private double percentExactMatch = 0; // Percentage of matching reads with no variation
  
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

     totalBases += readLength;
     totalValidBases += countValidBases(record.getReadString());

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
        
        numMismatches = mCtr.countMismatches(record);
      
        if(numMismatches == 0)
        {
          totalExactMatches++;
        }
        totalMismatches += numMismatches;
     }
  }
  
  /**
   * Compute alignment results
   */
  public void calculateAlignmentResults()
  {
    if(totalReads > 0)
    {
      percentMapped = 1.0 * mappedReads / totalReads * 100;
      
      if(mappedReads > 0)
      {
        percentDup = 1.0 * dupReads / mappedReads * 100.0;
        percentExactMatch = 1.0 * totalExactMatches / mappedReads * 100;
      }
      else
      {
        percentDup = 0;
        percentExactMatch = 0;
      }
      
      if(totalMappedBases > 0)
        percentMismatch = 1.0 * totalMismatches / totalMappedBases * 100.0;
      else
        percentMismatch = 100;
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
   * Count the number of valid bases in a read. Valid bases are the ones without Ns
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
  
  public String toString()
  {
    if(totalReads <= 0)
      return "";
    
    String newLine = "\r\n";
    StringBuilder resultString = new StringBuilder("Alignment Results - Read Type : " + readName);
    resultString.append(newLine);
    resultString.append(newLine);
    resultString.append("Total Reads       : " + totalReads + newLine);
    resultString.append("Unmapped Reads    : " + unmappedReads + newLine);
    resultString.append("Mapped Reads      : " + mappedReads + newLine);
    resultString.append("% Mapped Reads    : " + String.format("%.2f", percentMapped) + "%");
    resultString.append(newLine);
    resultString.append("% Mismatch        : " + String.format("%.2f", percentMismatch) + "%");
    resultString.append(newLine);
    resultString.append(newLine);
    resultString.append("Duplicate Reads   : " + dupReads + newLine);
    resultString.append("% Duplicate Reads : " + String.format("%.2f", percentDup) + "%");
    resultString.append(newLine);
    resultString.append(newLine);
    resultString.append("Exact Match Reads : " + totalExactMatches + newLine);
    resultString.append("% Exact Match Reads : " + String.format("%.2f", percentExactMatch) + "%");
    resultString.append(newLine);
    resultString.append(newLine);
    resultString.append("Total Bases (including Ns)       : " + totalBases + newLine);
    resultString.append("Total Valid Bases (excluding Ns) : " + totalValidBases + newLine);
    resultString.append(newLine);
    return resultString.toString();
  }
  
  public Element toXML(Document doc)
  {
    if(totalReads <= 0)
      return null;
    
    Element rootNode = doc.createElement("AlignmentResults");
    rootNode.setAttribute("ReadType", readName);
    
    Element readInfo = doc.createElement("ReadInfo");
    readInfo.setAttribute("TotalReads", String.valueOf(totalReads));
    readInfo.setAttribute("MappedReads", String.valueOf(mappedReads));
    readInfo.setAttribute("PercentMapped", String.valueOf(percentMapped));
    readInfo.setAttribute("PercentMismatch", String.valueOf(percentMismatch));
    readInfo.setAttribute("PercentDuplicate", String.valueOf(percentDup));
    readInfo.setAttribute("PercentExactMatch", String.valueOf(percentExactMatch));
    rootNode.appendChild(readInfo);
    
    Element yieldInfo = doc.createElement("YieldInfo");
    yieldInfo.setAttribute("TotalBases", String.valueOf(totalBases));
    yieldInfo.setAttribute("ValidBases", String.valueOf(totalValidBases));
    rootNode.appendChild(yieldInfo);
    return rootNode;
  }
}
