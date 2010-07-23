import java.io.*;
import java.util.*;

/**
 * @author niravs
 * Class to parse Illumina export file to extract the reads that map to
 * phix reference
 */
public class ExportFileFilter
{
  private String exportFileName = null;  // Name of export file
  private long totalReads       = 0;     // Total reads in export file
  private long discardedReads   = 0;     // Total reads removed (phix)
  
  // To remember reads that map to Phix
  private Hashtable<String, String> phixReads = null;

  private BufferedReader reader      = null; // Instance of file reader
  private BufferedWriter writer      = null; // To write new file

  /**
   * Class constructor
   */ 
  public ExportFileFilter(String exportFileName) throws Exception
  {
    this.exportFileName = exportFileName;
    reader    = new BufferedReader(new FileReader(exportFileName));
    phixReads = new Hashtable<String, String>();
  }

  /**
   * Method to remove reads that align to phix from export file
   */
  public Hashtable<String, String> filterPhixReads() throws Exception
  {
    String line;
    String tokens[];

    File outputFile = new File(exportFileName + ".filtered");
    writer = new BufferedWriter(new FileWriter(outputFile));
    
    while((line = reader.readLine()) != null)
    {
      totalReads++;
      tokens = line.split("\t");

      if(readMapsToPhix(tokens))
      {
        discardedReads++;
        phixReads.put(getReadName(tokens), "");
      }
      else
      {
        writer.write(line);
        writer.newLine();
      }
      tokens = null;
      line = null;
    }
    writer.close();
    reader.close();
    File f = new File(exportFileName);
    f.delete();
    outputFile.renameTo(new File(exportFileName));
    
    System.out.println("Filtering     : " + exportFileName);
    System.out.println("Total Reads   : " + totalReads);
    System.out.println("Reads Removed : " + discardedReads);
    System.out.format("%% Reads Removed : %.2f %%",  1.0 * discardedReads / totalReads * 100.0);
    System.out.println();
    return phixReads;
  }
  
  /**
   * Method that checks if a read maps to phix reference
   * @param tokens
   * @return
   */
  private boolean readMapsToPhix(String tokens[])
  {
    //11th field (index 10) represents the mapping information.
    if(tokens.length < 11)
    {
      return false;
    }
    if(tokens[10].toLowerCase().startsWith("phix"))
    {
      return true;
    }
    else
    {
      return false;
    }
  }
 
  /**
   * Private helper method to build read name from export file
   */ 
  private String getReadName(String tokens[]) throws Exception
  {
    if(tokens.length < 6)
    {
      throw new Exception("Invalid read");
    }
    return tokens[2] + ":" + tokens[3] + ":" + tokens[4] +
           ":" + tokens[5] + "#" + tokens[6] + "/" + tokens[7];
  }
}

