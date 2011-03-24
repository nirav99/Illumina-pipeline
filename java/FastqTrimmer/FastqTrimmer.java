/**
 * Class to trim fastq sequence files based on base start position and the
 * number of bases.
 */
import net.sf.picard.cmdline.*;
import net.sf.picard.fastq.FastqReader;
import net.sf.picard.fastq.FastqRecord;
import net.sf.picard.fastq.FastqWriter;
import net.sf.picard.io.IoUtil;
import java.io.*;

/**
 * @author Nirav Shah niravs@bcm.edu
 * Class to trim fastq files in sequence space
 */
public class FastqTrimmer extends  CommandLineProgram
{
  @Usage
  public String USAGE = getStandardUsagePreamble() +
  "Read Fastq file and trim the reads.\r\n";
	  
  @Option(shortName = StandardOptionDefinitions.INPUT_SHORT_NAME, doc = "Fastq file to trim")
  public File INPUT;
  
  @Option(shortName = StandardOptionDefinitions.OUTPUT_SHORT_NAME, doc = "Trimmed Fastq file")
  public File OUTPUT;
  
  @Option(shortName = "TS", doc = "Starting position (1-based) to trim")
  public int trimStartPosition;
  
  @Option(shortName = "NT", doc = "Number of bases to trim starting from (TS)")
  public int numBasesToTrim = 0;
  
  // Read length
  protected int readLen = 0;
  
  public static void main(String[] args)
  {
    new FastqTrimmer().instanceMainWithExit(args);
  }
  
  @Override
  protected int doWork()
  {
    FastqReader reader = null;
    FastqWriter writer = null;
    FastqRecord record = null;
    long numReads      = 0;
    
    try
    {
      IoUtil.assertFileIsReadable(INPUT);
      IoUtil.assertFileIsWritable(OUTPUT);
      
      reader = new FastqReader(INPUT);
      writer = new FastqWriter(OUTPUT);
    
      record = reader.next();
      readLen = record.getReadString().length();
      
      if(trimStartPosition < 1 || trimStartPosition >= readLen)
        throw new Exception("Invalid value for trimStartLength");
      if(numBasesToTrim < 1)
			throw new Exception("Number of bases to remove must be at least 1.");
      
      writer.write(trimReads(record));
      
      while(reader.hasNext())
      {
        record = reader.next();
        writer.write(trimReads(record));
        record = null;
        numReads++;
        
        if(numReads % 1000000 == 0)
        {
          System.err.print("Processing Read : " + numReads + "\r");
        }
      }
      reader.close();
      writer.close();
      return 0;
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
      return -1;
    }
  }
  
  protected FastqRecord trimReads(FastqRecord record)
  {
	int nextPosition = trimStartPosition + numBasesToTrim -1;
    StringBuilder readString = new StringBuilder();
    StringBuilder qualString = new StringBuilder();
    readString.append(record.getReadString().substring(0, trimStartPosition -1));
    qualString.append(record.getBaseQualityString().substring(0, trimStartPosition -1));
    
    if(nextPosition < readLen)
    {
      readString.append(record.getReadString().substring(nextPosition));
      qualString.append(record.getBaseQualityString().substring(nextPosition));
    }
    FastqRecord rec = new FastqRecord(record.getReadHeader(), readString.toString(), 
				                              record.getBaseQualityHeader(), qualString.toString());
    return rec;
  }
}
