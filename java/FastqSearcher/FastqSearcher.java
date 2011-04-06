/**
 * Class to search a fastq file for a specific record
 */
import net.sf.picard.cmdline.*;
import net.sf.picard.fastq.FastqReader;
import net.sf.picard.fastq.FastqRecord;
import net.sf.picard.io.IoUtil;
import java.io.*;

/**
 * @author Nirav Shah niravs@bcm.edu
 * Class to search for a specific fastq read
 */
public class FastqSearcher extends CommandLineProgram
{
  @Usage
  public String USAGE = getStandardUsagePreamble() +
                        "Read Fastq file and search for a specific read.\r\n";
		  
  @Option(shortName = StandardOptionDefinitions.INPUT_SHORT_NAME, doc = "Fastq file ")
  public File INPUT;

  @Option(shortName = "S", doc = "Name of read to search for")
  public String searchRecord;

  public static void main(String[] args)
  {
    new FastqSearcher().instanceMainWithExit(args);
  }
  
  @Override
  protected int doWork()
  {
    FastqReader reader = null;
    FastqRecord record = null;
    long numReads = 0;
    boolean found = false;
    
    try
    {
      IoUtil.assertFileIsReadable(INPUT);
      reader = new FastqReader(INPUT);
      
      while(reader.hasNext() && !found)
      {
        record = reader.next();
        numReads++;
        
        if(record.getReadHeader().startsWith(searchRecord))
        {
          found = true;
          System.out.println("Found Read : " + searchRecord);
          System.out.println(record.getReadHeader());
          System.out.println(record.getReadString());
          System.out.println(record.getBaseQualityHeader());
          System.out.println(record.getBaseQualityString());
        }
        if(numReads % 1000000 == 0)
        {
          System.err.print("Processing Read : " + numReads + "\r");
        }
        record = null;
      }
      if(!found)
      {
        System.out.println("Did not find read " + searchRecord);
      }
      return 0;
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
      return -1;
    }
  }
}
