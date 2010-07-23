import java.io.*;
import java.util.*;
import net.sf.picard.PicardException;
import net.sf.picard.fastq.FastqReader;
import net.sf.picard.fastq.FastqRecord;
import net.sf.picard.fastq.FastqWriter;
import net.sf.picard.io.IoUtil;
import net.sf.picard.util.FastqQualityFormat;
import net.sf.picard.util.SolexaQualityConverter;

/**
 * @author niravs
 * Class to remove sequences mapping to phix reads from Illumina sequence
 * (fasta)
 * files
 */
public class SequenceFileFilter
{
  private String fastQSequence = null;  // Name of Illumina fastq sequence file
  private FastqReader reader   = null;  // Reference to FastqReader from picard
  private FastqWriter writer   = null;  // Reference to FastqWriter from picard
  private String outputFile    = null;  // Name of temporary output file
  
  private long totalReads      = 0;
  private long discardedReads  = 0;

  // Reads to discard from sequence file
  private Hashtable<String,String> phixReads = null;
  
  /**
   * Class constructor
   * @param seqFileName
   * @param phixReads
   */
  public SequenceFileFilter(String seqFileName, 
                            Hashtable<String, String> phixReads)
  {
    this.fastQSequence = seqFileName;
    this.phixReads = phixReads;
    this.outputFile = seqFileName + ".filtered";  
    
    reader = new FastqReader(new File(fastQSequence));
    writer = new FastqWriter(new File(outputFile));
  }

  /**
   * Method to filter reads mapping to phix from sequence file
   */
  public void filterPhixReads()
  {
    while(reader.hasNext())
    {
      FastqRecord record = reader.next();
      
      totalReads++;
      
      if(false == removeRecord(record))
      {
        writer.write(record);
      }
      else
      {
        discardedReads++;
      }
    }
    reader.close();
    writer.close();
    
    // Replace the original FastQ sequence file with the new file
    File f = new File(fastQSequence);
    f.delete();
    File f2 = new File(outputFile);
    f2.renameTo(f);
    
    System.out.println("Filtering     : " + fastQSequence);
    System.out.println("Total Reads   : " + totalReads);
    System.out.println("Reads Removed : " + discardedReads);
    System.out.format("%% Reads Removed : %.2f %%",  1.0 * discardedReads / totalReads * 100.0);
    System.out.println();
  }
  
  /**
   * Private helper method to determine if the current fastq read should
   * be filtered from the output file
   * @param record
   * @return
   */
  private boolean removeRecord(FastqRecord record)
  {
//    System.out.println(getReadName(record));
//    System.out.println();
    if(phixReads.containsKey(getReadName(record)))
    {
      return true;
    }
    return false;
  }
 
  private String getReadName(FastqRecord record)
  {
    // Discard the machine name and run number from read name
    int idx = record.getReadHeader().indexOf(":");
    String readName = record.getReadHeader().substring(idx + 1);
    return readName;
  }
 
  private void showKeys()
  {
    Enumeration<String> keys = phixReads.keys();
    while(keys.hasMoreElements())
      System.out.println(keys.nextElement());
  }
}

