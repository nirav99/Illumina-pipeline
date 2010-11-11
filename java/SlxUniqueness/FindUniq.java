/**
 * This class is used to calculate the total reads and the unique reads
 * in the specified file.
 * The records are sorted and then total reads and unique reads are computed.
 * However, for large input files, an external sorting approach based on merge
 * sort is used to calculate the number of total reads and unique reads.
 */
import java.io.*;
import java.util.*;

/**
 * @author niravs
 *
 */
public class FindUniq
{
  private int MAXRECORDS = 10000000;    // Max records to store in memory
  private Result result;                // Uniqueness result reference
  private CmdParams inputParam;         // Input parameters to the program
  private String memoryBuffer[];        // Stores records in memory
  private ArrayList<File> tempFileList; // List of temporary files
  private int iterationIdx;             // To access memory buffer array
  private BufferedReader inputFile;     // File to find unique elements from
  private File tempDir;                 // Temporary directory
  
  /**
   * Class constructor - initialize class members
   * @param inputParam - Reference to CmdParams
   */
  public FindUniq(CmdParams inputParam, File sourceFile) throws Exception
  {
    this.inputParam = inputParam;
    inputFile = new BufferedReader(new FileReader(sourceFile));
    result = new Result();
    memoryBuffer = new String[MAXRECORDS];
    tempFileList = new ArrayList<File>();
    iterationIdx = 0;
    tempDir = new File(inputParam.tempDir);
  }
  
  public Result findUniqueElements() throws Exception
  {
    readInputFile();
    return result;
  }
  
  /**
   * Method to read the input file and generate temporary files.
   * @throws Exception
   */
  private void readInputFile() throws Exception
  {
    String line;
    
    while((line = inputFile.readLine()) != null)
    {
      // The number of records exceeded threshold, so
      // write them to a temporary file.
      if(iterationIdx >= MAXRECORDS)
      {
        spillToTempFile(memoryBuffer.length);
        iterationIdx = 0;
      }
      memoryBuffer[iterationIdx++] = line;
    }
    
    /*
     * The total number of records in file was less than the the maximum
     * limit. Hence, perform in-memory uniqueness computation. 
     */
    if(tempFileList.isEmpty())
    {
      countUnique(iterationIdx);
    }
    else
    {
      spillToTempFile(iterationIdx);
      MergeAndComputeResults merge = new MergeAndComputeResults(tempFileList);
      result = merge.mergeAndComputeResults();
    }
  }
  
  /**
   * Helper method to sort the records in memory and write them to a temporary
   * file on disk.
   * @param size - Number of records to sort
   * @throws Exception
   */
  private void spillToTempFile(int size) throws Exception
  {
    File tempFile = File.createTempFile("uniqsegment", ".tmp", tempDir);
    tempFile.deleteOnExit();
    
    BufferedWriter writer = new BufferedWriter(new FileWriter(tempFile));
    tempFileList.add(tempFile);
    
    Arrays.sort(memoryBuffer, 0, size);
    
    for(int i = 0; i < size; i++)
    {
      writer.write(memoryBuffer[i]);
      writer.newLine();
    }
    writer.close();
  }
  
  /**
   * Calculate the unique records from the records in memory
   * @param size
   */
  private void countUnique(int size)
  {
    String lastRecord = "";
    String nextRecord = "";
    
    result.totalReads += size;
    
    Arrays.sort(memoryBuffer, 0, size);
    
    for(int i = 0; i < size; i++)
    {
      nextRecord = memoryBuffer[i];
      
      if(!nextRecord.equalsIgnoreCase(lastRecord))
      {
        result.uniqueReads++;
      }
      lastRecord = nextRecord;
    }
  }
}

/**
 * Helper class that merges temp files and gets uniqueness results
 * @author niravs
 *
 */
class MergeAndComputeResults
{
  private PriorityQueue<String> pQueue; // To get least string
  private String setOfLines[];          // Next set of lines
  private BufferedReader readerList[];  // List of file readers
  private Result result;                // Uniqueness result
  
  /**
   * Class constructor - initialize internal data structures
   * @param tempFileList - Temp file list
   * @throws Exception
   */
  MergeAndComputeResults(ArrayList<File> tempFileList) throws Exception
  {
    setOfLines = new String[tempFileList.size()];
    readerList = new BufferedReader[tempFileList.size()];
    pQueue = new PriorityQueue<String>();
    result = new Result();
    
 // Create instances of readers to read temp files
    for(int i = 0; i < tempFileList.size(); i++)
    {
      readerList[i] = new BufferedReader(new FileReader(tempFileList.get(i)));
    }
  }
 
  /**
   * Method to merge files and obtain uniqueness results
   * @return
   * @throws Exception
   */
  Result mergeAndComputeResults() throws Exception
  {
    String last = "";
    String next = "";
    
    readNextLines();
    
    while(true)
    {
      if(allStringNull())
      {
        break;
      }
      next = pQueue.poll();
      result.totalReads++;
      
      if(!next.equalsIgnoreCase(last))
      {
        result.uniqueReads++;
      }
      last = next;
      
      for(int i = 0; i < setOfLines.length; i++)
      {
        if(next.equalsIgnoreCase(setOfLines[i]))
        {
          addNextLine(i);
        }
      }
    }
 // Now Priority Queue is empty
    while(!pQueue.isEmpty())
    {
      next = pQueue.poll();
      result.totalReads++;
      if(!next.equalsIgnoreCase(last))
      {
        result.uniqueReads++;
      }
      last = next;
    }
    closeFiles();
    return result;
  }
  
  /**
   * To test if entire array is null
   * @return - true if entire array is null, false otherwise
   */
  private boolean allStringNull()
  {
    for(int i = 0; i < setOfLines.length; i++)
    {
      if(setOfLines[i] != null)
      {
        return false;
      }
    }
    return true;
  }
  
  /**
   * Read next line from each open file
   * @throws Exception
   */
  private void readNextLines() throws Exception
  {
    for(int i = 0; i < readerList.length; i++)
    {
      addNextLine(i);
    }
  }
  
  private void addNextLine(int i) throws Exception
  {
    setOfLines[i] = readerList[i].readLine();
    if(setOfLines[i] != null)
    {
      pQueue.offer(setOfLines[i]);
    }
  }
  
  /**
   * Close all open files
   */
  private void closeFiles()
  {
    try
    {
      for(int i = 0; i < readerList.length; i++)
      {
        readerList[i].close();
      }
    }
    catch(Exception e)
    {
      // Swallow it for now
    }
  }
}
