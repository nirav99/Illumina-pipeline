/**
 * Class to calculate alignment and various metrics for a BAM.
 */
import net.sf.samtools.*;
import net.sf.samtools.SAMFileReader.ValidationStringency;
import net.sf.samtools.util.RuntimeIOException;
import net.sf.picard.cmdline.*;
import net.sf.picard.io.IoUtil;
import java.io.File;
import java.io.IOException;

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class BAMAnalyzer extends CommandLineProgram
{
  @Usage
  public String USAGE = getStandardUsagePreamble() +
  "Read SAM / BAM and calculate alignment and insert size metrics.\r\n";

    @Option(shortName = StandardOptionDefinitions.INPUT_SHORT_NAME, doc = "Input SAM/BAM to process.")
    public File INPUT;
    
  /**
   * @param args
   */
  public static void main(String[] args)
  {
    new BAMAnalyzer().instanceMainWithExit(args);
  }
  
  @Override
  protected int doWork()
  {
    SAMFileReader reader          = null;  // To read a BAM file
    long totalReads               = 0;     // Total Reads in BAM file
    InsertSizeCalculator insCalc  = null;  // Class to calculate insert size
    PairStatsCalculator pairCalc  = null;  // Calculate information of read pairs
    AlignmentCalculator alignCalc = null;  // Calculate alignment information
    QualPerPosCalculator qualCalc = null;  // Calculate avg. base quality per base position
    try
    {
      IoUtil.assertFileIsReadable(INPUT);
    
      SAMFileReader.setDefaultValidationStringency(ValidationStringency.SILENT);
      reader = new SAMFileReader(INPUT);
  
      alignCalc = new AlignmentCalculator();
      insCalc   = new InsertSizeCalculator();
      pairCalc  = new PairStatsCalculator();
      qualCalc  = new QualPerPosCalculator();
      
      long startTime = System.currentTimeMillis();
    
      for(SAMRecord record : reader)
      {
        totalReads++;
      
        if(totalReads > 0 && totalReads % 1000000 == 0)
        {
          System.err.print("\r" + totalReads);
        }
        
        alignCalc.processRead(record);
        insCalc.processRead(record);
        pairCalc.processRead(record);
        qualCalc.processRead(record);
      }
    
      long stopTime = System.currentTimeMillis();
    
      reader.close();
  
      System.out.println();
      System.out.println("Total Reads in File : " + totalReads);
      alignCalc.showResult();
      insCalc.showResult();
      pairCalc.showResult();
      qualCalc.showResult();
      System.out.format("%nComputation Time      : %.3f sec%n%n", (stopTime - startTime)/1000.0);
      return 0;
  }
  catch(Exception e)
  {
    System.out.println(e.getMessage());
    e.printStackTrace();
    return -1;
  }
 }
}
