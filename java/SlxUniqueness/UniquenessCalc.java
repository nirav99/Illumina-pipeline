import java.util.*;
import java.io.*;

/**
 * Class to calculate uniqueness for specified sequence files
 */

/**
 * @author niravs
 *
 */
public class UniquenessCalc
{
  private int prefixLength = 5;  // To split sequences into different files
                                 // based
                                 // on read prefix
  private int seedLength = 31;   // Length of sequences from beginning of the
                                 // read
                                 // to consider for uniqueness computation
  private CmdParams inputParams; // Preserve input parameters
 
  // Table holding references to intermediate files
  private Hashtable<String, BufferedWriter>prefixTable;

  // Instance of class to calculate sequences having adaptor  
  private FindAdaptorSequence adapSeq = null;
  private boolean calculateAdaptorSeq = false;

  // Instance of class to calculate bad reads
  private FindBadReads badReadsFinder = null;

  // Results to compute and display
  private long totalReads  = 0;
  private long uniqueReads = 0;
  
  /**
   * Class constructor
   * @param inputParams - Command line parameters
   * @throws Exception
   */
  public UniquenessCalc(CmdParams inputParams) throws Exception
  {
    this.inputParams = inputParams;
    prefixTable = new Hashtable<String, BufferedWriter>();

    if(inputParams.detectAdaptors == true)
    {
      calculateAdaptorSeq = true;
    }

    badReadsFinder = new FindBadReads();
/*
    if(inputParams.adaptorFile != null)
    {
      calculateAdaptorSeq = true;
      adapSeq = new FindAdaptorSequence(inputParams.adaptorFile);
    }
*/
  }
  
  /**
   * Method to analyze sequence files
   * @throws Exception
   */
  public void process() throws Exception
  {
    if(inputParams.mode == AnalysisMode.FRAGMENT)
    {
      readFiles();
    }
    else
    {
      readFilesMatePair();
    }
    findDups();
  }
  
  /**
   * Helper method to generate search keys for fragment analysis mode 
   * @throws Exception
   */
  private void readFiles() throws Exception 
  {
    String line;
    String lineToWrite;
    String fileNames[] = inputParams.inputFiles;
  
    for(int i = 0; i < fileNames.length; i++)
    {
      BufferedReader br = new BufferedReader(new FileReader(fileNames[i]));
      System.err.println("Reading " + fileNames[i]);
      
      while((line = br.readLine()) != null)
      {
        if(line.startsWith("@"))
        {
          line = br.readLine();

          if(calculateAdaptorSeq)
          {
            if(adapSeq == null)
            {
              adapSeq = new FindAdaptorSequence(line.length());
            }
            adapSeq.checkRead(line, 1);
          }

          badReadsFinder.checkRead(line, 1);

          lineToWrite = line.substring(0, seedLength - 1);
          writeToTempFile(lineToWrite);
        }
        line = null;
      }
      br.close();
      br = null;
    }
    for(BufferedWriter wr: prefixTable.values())
    {
      wr.close();
    }
    System.err.println("Generated intermediate files");
  }

  /**
   * Helper method to generate search keys for paired analysis mode
   */
  private void readFilesMatePair() throws Exception
  {
    String line1, line2;
    String lineToWrite;
    
    String fileNames[] = inputParams.inputFiles;
    
    for(int i = 0; i < fileNames.length - 1; i += 2)
    {
      int file1 = i;
      int file2 = i + 1;
      BufferedReader br1 = new BufferedReader(new FileReader(fileNames[file1]));
      System.err.println("Reading " + fileNames[file1]);
      
      BufferedReader br2 = new BufferedReader(new FileReader(fileNames[file2]));
      System.err.println("Reading " + fileNames[file2]);
      
      // Both files have data - 
      // TODO: if one of them has less data that must be considered
      while(((line1 = br1.readLine()) != null) && ((line2 = br2.readLine()) != null))
      {
        if(line1.startsWith("@") && line2.startsWith("@"))
        {
          /**
           * If the Read IDs for paired reads are different, don't process
           * those reads, instead throw an exception and abort.
           */
          if(!line1.substring(0, line1.length() - 1).equalsIgnoreCase(line2.substring(0, line2.length() - 1)))
          {
            throw new Exception("Read IDs are different : " + line1 + " " + line2);
          }
          line1 = br1.readLine();
          line2 = br2.readLine();
       
          if(calculateAdaptorSeq)
          {
            if(adapSeq == null)
            {
              adapSeq = new FindAdaptorSequence(line1.length());
            }
            adapSeq.checkRead(line1, 1);
            adapSeq.checkRead(line2, 2);
          } 
          badReadsFinder.checkRead(line1, 1);
          badReadsFinder.checkRead(line2, 2);

          lineToWrite = line1.substring(0, seedLength - 1) + line2.substring(0, seedLength -1);
          writeToTempFile(lineToWrite);
          lineToWrite = null;
        }
      }
      br1.close();
      br2.close();
      br1 = null;
      br2 = null;
    }
    for(BufferedWriter wr: prefixTable.values())
    {
      wr.close();
    }
    System.err.println("Generated intermediate files");
  }

  /**
   * Helper method to write read string to correct intermediate file
   * @param String representing read to store to temporary file
   * @throws IOException 
   */
  private void writeToTempFile(String readSequence) throws IOException
  {
   /**
    * Generate a prefix of specified length and use that as key in
    * hashtable to locate correct file to write readSequence to.
    */
    String key = readSequence.substring(0, prefixLength - 1);

    /**
     * If the temp file corresponding to this read was already opened,
     * retrieve that file handle and write the read string to it.
     * Otherwise, create a new file, write the read string and
     * and store its handle in the hashtable.
     */
    if(prefixTable.containsKey(key))
    {
      BufferedWriter writer = prefixTable.get(key);
      writer.write(readSequence);
      writer.newLine();
      writer = null;
    }
    else
    {
      File tempFile = buildFilePath(inputParams.tempDir, key + ".seq");
      BufferedWriter writer = new BufferedWriter(new FileWriter(tempFile));
      writer.write(readSequence);
      writer.newLine();
      prefixTable.put(key, writer);
      writer = null;
    }
  }  
  
  /**
   * Helper method to analyze the intermediate files and report results
   * @throws Exception
   */
  private void findDups() throws Exception
  {
    Enumeration<String> e = prefixTable.keys();
 
    System.err.println("Reading intermediate files"); 
    while(e.hasMoreElements())
    {
      String fileName = e.nextElement() + ".seq";
      System.err.println("Reading : " + fileName);
      File toRead = buildFilePath(inputParams.tempDir, fileName);

      FindUniq uniq = new FindUniq(inputParams, toRead);
      Result res = uniq.findUniqueElements();

      totalReads += res.totalReads;
      uniqueReads += res.uniqueReads;
    }
    
    System.out.println("");
    System.out.println("Unique Reads");
    System.out.println("Total Reads    : " + totalReads);
    System.out.println("Unique Reads   : " + uniqueReads);
    System.out.format("%% Unique Reads : %.2f %%",  1.0 * uniqueReads / totalReads * 100.0);
    System.out.println("");

    if(calculateAdaptorSeq)
    {
      System.out.println("");
      System.out.println("Adaptor Reads");
      AdaptorCount adapCount = adapSeq.getAdaptorCount();
      adapCount.showResult();
    }
    
    System.out.println("");
    System.out.println("Bad Reads");
    BadReadCount bCount = badReadsFinder.getBadReadCount();
    bCount.showResult();
  }
  
  /**
   * Helper method to get a "File" instance, given directory name and file name
   * @param dirPath - Path to directory
   * @param fileName - Name of file
   * @return - File object corresponding to dirPath and fileName
   */
  private File buildFilePath(String dirPath, String fileName)
  {
    File f = new File(dirPath, fileName);
    return f;
  }
}
