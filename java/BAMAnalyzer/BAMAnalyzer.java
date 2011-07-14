import net.sf.samtools.*;
import net.sf.samtools.SAMFileReader.ValidationStringency;
import net.sf.picard.cmdline.*;
import net.sf.picard.io.IoUtil;
import java.io.File;
import java.util.*;

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
	    
  @Option(doc = "Stop after debugging N reads. Mainly for debugging. Default value: 0, which means process the whole file")
  public int STOP_AFTER = 0;
	    
  @Option(shortName = StandardOptionDefinitions.OUTPUT_SHORT_NAME, doc = "Output file to write results in txt format", optional=true)
  public File OUTPUT;

  @Option(shortName = "X", doc = "File with results in XML format", optional=true)
  public File XMLOUTPUT;
  
  public static void main(String[] args)
  {
    new BAMAnalyzer().instanceMainWithExit(args);
  }
  
  @Override
  protected int doWork()
  {
    SAMFileReader reader  = null;  // To read a BAM file
    long totalReads       = 0;     // Total Reads in BAM file
    
    try
    {
      IoUtil.assertFileIsReadable(INPUT);
    
      SAMFileReader.setDefaultValidationStringency(ValidationStringency.SILENT);
      reader = new SAMFileReader(INPUT);
      
      ArrayList<MetricsCalculator> metrics = new ArrayList<MetricsCalculator>();
      
      metrics.add(new AlignmentCalculator(ReadType.READ1));
      metrics.add(new AlignmentCalculator(ReadType.READ2));
      metrics.add(new AlignmentCalculator(ReadType.FRAGMENT));
      metrics.add(new InsertSizeCalculator());  
      metrics.add(new PairStatsCalculator());
      metrics.add(new QualPerPosnCalculator());
      
      for(SAMRecord record : reader)
      {
        totalReads++;
      
        if(totalReads > 0 && totalReads % 1000000 == 0)
          System.err.print("\r" + totalReads);
       
        for(int i = 0; i < metrics.size(); i++)
          metrics.get(i).processRead(record);
        
        if(STOP_AFTER > 0 && totalReads > STOP_AFTER)
            break;
      }
      reader.close();

      ArrayList<ResultMetric> resultMetrics = new ArrayList<ResultMetric>();
      
      for(int i = 0; i < metrics.size(); i++)
      {
        metrics.get(i).calculateResult();
        metrics.get(i).buildResultMetrics();
        if(metrics.get(i).getResultMetrics() != null)
          resultMetrics.add(metrics.get(i).getResultMetrics());
      }

      ArrayList<Logger> loggers = new ArrayList<Logger>();

      if(OUTPUT != null)
        loggers.add(new TextLogger(OUTPUT));
      if(XMLOUTPUT != null)
        loggers.add(new XmlLogger(XMLOUTPUT));
      
      for(int i = 0; i < resultMetrics.size(); i++)
      {
        for(int j = 0; j < loggers.size(); j++)
          loggers.get(j).logResult(resultMetrics.get(i));
      }
 
      for(int i = 0; i < loggers.size(); i++)
        loggers.get(i).closeFile();

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
