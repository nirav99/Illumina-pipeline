/**
 * Class to encapsulate the function "main"
 */
import java.io.*;

/**
 * @author niravs
 *
 */
public class Driver
{

  /**
   * @param args
   */
  public static void main(String[] args)
  {
    if(args.length != 1)
    {
      printUsage();
      System.exit(-1);
    }
	
    String fileToAnalyze = args[0];
    File f = new File(fileToAnalyze);
	
    if(!f.exists() || !f.canRead() || !f.isFile())
    {
      System.err.println("Specified file does not exist or is not a regular file");
      System.exit(-2);
    }
    
    MapStatsCalculator calc = new MapStatsCalculator(args[0]);
  }
  
  private static void printUsage()
  {
    System.err.println("Usage :");
    System.err.println("java -jar BAMAnalysis.jar BamFileName");
    System.err.println("    BamFileName - BAM/SAM file to analyze");
  }
}

