import java.util.*;
import java.io.*;

public class Driver
{
  /**
   * @param args
   */
  public static void main(String[] args)
  {
	String seqFileRead1 = null;
	String seqFileRead2 = null;
	
    if(args.length < 1 || args.length > 2)
    {
      printUsage();
      System.exit(-1);
    }
    try
    {
      validateArgs(args);
      PhixFinder expFilter = null;
      
      if(args.length == 1)
      {
        expFilter = new PhixFinder(args[0], null);
        seqFileRead1 = args[0].replace("export", "sequence");
      }
      else
      {
        expFilter = new PhixFinder(args[0], args[1]);
        seqFileRead1 = args[0].replace("export", "sequence");
        seqFileRead2 = args[1].replace("export", "sequence");
      }
      
      Hashtable<String, String> phixReads = expFilter.getPhixReads();
      expFilter.filterPhixReads();
      SequenceFileFilter seqFilter = new SequenceFileFilter(seqFileRead1, phixReads);
      seqFilter.filterPhixReads();
      seqFilter = null;
      
      if(seqFileRead2 != null)
      {
        seqFilter = new SequenceFileFilter(seqFileRead2, phixReads);
        seqFilter.filterPhixReads();
        seqFilter = null;
      }
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
      System.exit(-1);
    }
  }
  
  private static void printUsage()
  {
    System.err.println("Usage :");
    System.err.println("java -jar FilterPhixReads.jar ExportFileRead1 ExportFileRead2");
    System.err.println("    ExportFileRead1 - Illumina Format Export File - Read1 or fragment");
    System.err.println("    ExportFileRead2 - (Optional) Export file for read2");
  }
  
  private static void validateArgs(String[] args)
  {
    filePresent(args[0]);
    String seqFile = args[0].replace("export", "sequence");
    filePresent(seqFile);
    
    if(args.length == 2)
    {
      filePresent(args[1]);
      seqFile = args[1].replace("export", "sequence");
      filePresent(seqFile);
    }
  }
  
  private static void filePresent(String fileName)
  {
    File f= new File(fileName);
    
    if(!f.exists() || !f.canRead() || !f.isFile())
    {
      System.err.println("Specified file : " + fileName + " cannot be read");
      System.exit(-1);
    }
  }
}
