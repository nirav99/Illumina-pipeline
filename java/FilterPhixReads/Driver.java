import java.util.*;

public class Driver
{
  /**
   * @param args
   */
  public static void main(String[] args)
  {
    if(args.length != 2)
    {
      printUsage();
      System.exit(-1);
    }
    try
    {
      ExportFileFilter expFilter = new ExportFileFilter(args[0]);
      Hashtable<String, String> phixReads = expFilter.filterPhixReads();
      SequenceFileFilter seqFilter = new SequenceFileFilter(args[1], phixReads);
      seqFilter.filterPhixReads();
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
    System.err.println("java -jar FilterPhixReads.jar ExportFile SequenceFile");
    System.err.println("    ExportFile   - Illumina Format Export File");
    System.err.println("    SequenceFile - Illumina Format (Fastq) Sequence File");
  }
}
