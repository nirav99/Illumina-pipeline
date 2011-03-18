/**
 * Class to calculate alignment and various metrics on a BAM.
 */
import net.sf.samtools.*;
import net.sf.samtools.SAMFileReader.ValidationStringency;
import net.sf.samtools.util.RuntimeIOException;
import net.sf.picard.cmdline.*;
/*
import net.sf.picard.cmdline.Option;
import net.sf.picard.cmdline.StandardOptionDefinitions;
import net.sf.picard.cmdline.Usage;
import net.sf.picard.cmdline.CommandLineProgram;
*/
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
    MismatchCounter mmCounter     = null;  // Count number of mismatches in a read
    AlignmentResults read1Results = null;  // Mapping results for read1
    AlignmentResults read2Results = null;  // Mapping results for read2
    AlignmentResults fragResults  = null;  // Mapping results for unpaired reads
    long totalReads               = 0;     // Total Reads in BAM file
    InsertSizeCalculator insCalc  = null;  // Class to calculate insert size
    PairStatsCalculator pairCalc = null;   // Calculate information of read pairs
    
    try
    {
      IoUtil.assertFileIsReadable(INPUT);
    
      SAMFileReader.setDefaultValidationStringency(ValidationStringency.SILENT);
      reader = new SAMFileReader(INPUT);
  
      mmCounter = new MismatchCounter();
      read1Results  = new AlignmentResults("Read1", mmCounter);
      read2Results  = new AlignmentResults("Read2", mmCounter);
      fragResults   = new AlignmentResults("Fragment", mmCounter);

      insCalc  = new InsertSizeCalculator();
      pairCalc = new PairStatsCalculator();
      
      long startTime = System.currentTimeMillis();
    
      for(SAMRecord record : reader)
      {
        totalReads++;
      
        if(totalReads > 0 && totalReads % 1000000 == 0)
        {
          System.err.print("\r" + totalReads);
        }
      
        if(record.getReadPairedFlag() && record.getFirstOfPairFlag())
          read1Results.processRead(record);
        else
        if(record.getReadPairedFlag() && record.getSecondOfPairFlag())
          read2Results.processRead(record);
        else
        if(!record.getReadPairedFlag())
          fragResults.processRead(record);
      
        insCalc.processRead(record);
        pairCalc.processRead(record);
      }
    
      long stopTime = System.currentTimeMillis();
    
      reader.close();
  
      System.out.println();
      System.out.println("Total Reads in File : " + totalReads);
      read1Results.showAlignmentResults();
      read2Results.showAlignmentResults();
      fragResults.showAlignmentResults();
      insCalc.showResult();
      pairCalc.showResult();
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
