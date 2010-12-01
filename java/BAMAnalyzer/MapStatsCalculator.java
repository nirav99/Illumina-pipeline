/**
 * Class to calculate the alignment results
 */
import net.sf.samtools.*;
import net.sf.samtools.SAMFileReader.ValidationStringency;
import java.io.*;

/**
 * @author niravs
 *
 */
public class MapStatsCalculator
{
  private SAMFileReader reader          = null;  // To read a BAM file
  private MismatchCounter mmCounter     = null;  // To count number of mismatches in a read
  private AlignmentResults read1Results = null;  // Mapping results for read1
  private AlignmentResults read2Results = null;  // Mapping results for read2
  private AlignmentResults fragResults  = null;  // Mapping results for unpaired reads
  private long totalReads               = 0;     // Total Reads in BAM file
  private InsertSizeCalculator insCalc  = null;  // Class to calculate insert size  

  /**
   * Class constructor
   * @param fileName
   */
  public MapStatsCalculator(String fileName)
  {
	  try
	  {
      SAMFileReader.setDefaultValidationStringency(ValidationStringency.SILENT);
      reader = new SAMFileReader(new File(fileName));
    
      mmCounter = new MismatchCounter();
      read1Results  = new AlignmentResults("Read1", mmCounter);
      read2Results  = new AlignmentResults("Read2", mmCounter);
      fragResults   = new AlignmentResults("Fragment", mmCounter);

      insCalc = new InsertSizeCalculator();
      
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
        
        insCalc.calculateInsertSize(record);
      }
      
      long stopTime = System.currentTimeMillis();
      
      reader.close();
    
      System.out.println();
      System.out.println("Total Reads in File : " + totalReads);
      read1Results.showAlignmentResults();
      read2Results.showAlignmentResults();
      fragResults.showAlignmentResults();
      insCalc.showResult();
      System.out.format("%nComputation Time      : %.3f sec%n%n", (stopTime - startTime)/1000.0);
	  }
	  catch(Exception e)
	  {
      System.out.println(e.getMessage());
      e.printStackTrace();
	  }
  }
}
