import java.io.*;
import java.util.*;

/**
 * @author niravs
 * Class to parse Illumina export file to extract the reads that map to
 * phix reference
 */
public class PhixFinder
{
  private String exportFileRead1 = null; // Name of export file for read 1
  private String exportFileRead2 = null; // Export file for read 2
  private long totalReads       = 0;     // Total reads in export file
  private long discardedReads   = 0;     // Total reads removed (phix)
  
  // To remember reads that map to Phix
  private Hashtable<String, String> phixReads = null;

  /**
   * Class constructor
   * @param exportFileRead1
   * @param exportFileRead2
   * @throws Exception
   */
  public PhixFinder(String exportFileRead1, String exportFileRead2) 
  throws Exception
  {
    this.exportFileRead1 = exportFileRead1;
    
    if(exportFileRead2 != null && !exportFileRead2.isEmpty())
    {
      this.exportFileRead2 = exportFileRead2;
    }
    phixReads = new Hashtable<String, String>();
  }

  /**
   * Method to obtain reads that map to phix
   * @return
   * @throws Exception
   */
  public Hashtable<String, String> getPhixReads() throws Exception
  {
    buildPhixReadsTable(exportFileRead1);
    
    if(exportFileRead2 != null)
    {
			buildPhixReadsTable(exportFileRead2);
    }
    return phixReads;
  }
  
  /**
   * Method to filter out phix reads from the export file(s)
   */
  public void filterPhixReads() throws Exception
  {
    removePhixReads(exportFileRead1);
    
    if(exportFileRead2 != null)
    {
      removePhixReads(exportFileRead2);
    }
  }
  
  /**
   * Helper method to remove reads mapping to phix
   * @param exportFile
   * @param outputFile
   * @throws Exception
   */
  private void removePhixReads(String exportFile) throws Exception
  {
    String line;
    String tokens[];
    String outputFile = exportFile + ".filtered";
    
    BufferedReader reader = new BufferedReader(new FileReader(exportFile));
    BufferedWriter writer = new BufferedWriter(new FileWriter(outputFile));
    
    while((line = reader.readLine()) != null)
    {
      totalReads++;
      tokens = line.split("\t");
      String readName = getReadName(tokens);
      
      if(!phixReads.containsKey(readName))
      {
        writer.write(line);
        writer.newLine();
      }
      else
      {
        discardedReads++;
      }
      tokens   = null;
      readName = null;
      line     = null;
    }
    reader.close();
    writer.close();
    
    System.out.println("Filtering     : " + exportFile);
    System.out.println("Total Reads   : " + totalReads);
    System.out.println("Phix Reads    : " + discardedReads);
    System.out.format("%% Reads         : %.2f %%",  1.0 * discardedReads / totalReads * 100.0);
    System.out.println();
    
    File f = new File(exportFile);
    f.delete();
    File f2 = new File(outputFile);
    f2.renameTo(f);
  }
  
  /**
   * Helper method to build a hashtable having names of reads to remove from
   * the sequence files
   * @param exportFileName
   * @throws Exception
   */
  private void buildPhixReadsTable(String exportFileName) throws Exception
  {
    String line;
    String tokens[];

    BufferedReader reader = new BufferedReader(new FileReader(exportFileName));
    
    while((line = reader.readLine()) != null)
    {
      tokens = line.split("\t");

      if(readMapsToPhix(tokens))
      {
        String readName = getReadName(tokens);
        if(!phixReads.containsKey(readName))
        {
          phixReads.put(readName, "");
        }
        readName = null;
      }
      
      tokens = null;
      line = null;
    }
    reader.close();
  }
  
  /**
   * Method that checks if a read maps to phix reference
   * @param tokens
   * @return
   */
  private boolean readMapsToPhix(String tokens[])
  {
    //11th field (index 10) represents the mapping information.
    // It represents the chromosome that this read maps to.
    // 18th field (index 17) represents the partner chromosome, where partner
    // paired end read maps to. We want to remove that read also.

    if(tokens.length < 11)
    {
      return false;
    }
    if(tokens[10].toLowerCase().startsWith("phix"))
    {
      // this read maps to phix reference
      return true;
    }
    if(tokens.length >= 18 && tokens[17].toLowerCase().startsWith("phix"))
    {
      // In paired end mode, mate of this read maps to phix reference
      return true;
    }
    else
    {
      return false;
    }
  }
  
  /**
   * Helper method to construct a read name for lookup in sequence file.
   * This read name contains the following fields : 
   * 1) lane
   * 2) tile
   * 3) X-coordinate of cluster
   * 4) Y-coordinate of cluster
   * 5) Index sequence
   * @param tokens
   * @return
   * @throws Exception
   */
  private String getReadName(String tokens[]) throws Exception
  {
    if(tokens.length < 7)
    {
      throw new Exception("Invalid read");
    }
    
    return tokens[2] + ":" + tokens[3] + ":" + 
           tokens[4] + ":" + tokens[5] + "#" + tokens[6];
  }
}
