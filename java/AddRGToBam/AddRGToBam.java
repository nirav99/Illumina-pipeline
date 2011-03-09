import java.io.*;
import java.io.File.*;
import java.util.Date;
import java.text.*;
import net.sf.samtools.*;
import net.sf.samtools.SAMFileReader.ValidationStringency;
import net.sf.samtools.util.CloseableIterator;
import net.sf.samtools.SAMReadGroupRecord;

public class AddRGToBam 
{
  private SAMFileHeader header = null;
  private SAMFileReader reader = null;
  private SAMFileWriter writer = null;
  private String readGroupID   = null;
  
  public AddRGToBam(InputParameters ip)
  {
    long numReads = 0;
    
    SAMFileReader.setDefaultValidationStringency(ValidationStringency.SILENT);
    reader = new SAMFileReader(new File(ip.getInputFile()));
    header = reader.getFileHeader();
    
    this.readGroupID = ip.getReadGroupID();
    
    SAMReadGroupRecord rgTag = new SAMReadGroupRecord(readGroupID);
    rgTag.setSample(ip.getSampleID());

    String libraryName = ip.getLibraryName();
    if(libraryName != null && !libraryName.isEmpty())
    {
      rgTag.setLibrary(libraryName);
    }
    rgTag.setRunDate(new Date());
    String platform = ip.getPlatformName();
    if(platform  != null && !platform.isEmpty())
    {
      rgTag.setPlatform(platform);
    } 

    String pUnit = ip.getPlatformUnitName();
    if(pUnit != null && !pUnit.isEmpty())
    {
      rgTag.setPlatformUnit(pUnit);
    }
    header.addReadGroup(rgTag);

    String center = ip.getCenterName();
    if(center != null && !center.isEmpty())
    {
      rgTag.setSequencingCenter(center);
    }
    if(ip.getProgramName() != null && ip.getProgramVersion() != null &&
       !ip.getProgramName().isEmpty() && !ip.getProgramVersion().isEmpty())
    {
      SAMProgramRecord pgRecord = new SAMProgramRecord(ip.getProgramName());
      pgRecord.setProgramVersion(ip.getProgramVersion());
      header.addProgramRecord(pgRecord);
    }

    writer = new SAMFileWriterFactory().makeSAMOrBAMWriter(header,true, 
				 new File(ip.getOutputFile()));
    
    for (final SAMRecord samRecord : reader)
    {
      samRecord.setAttribute("RG", readGroupID);
      writer.addAlignment(samRecord);
      
      numReads++;
      
      if(numReads % 10000000 == 0)
      {
        System.err.println("\r" + numReads);
      }
    }
    writer.close();
    reader.close();
  }

  // Gets the date in ISO8601 format
  private String getDate()
  {
    Date d = new Date();
    SimpleDateFormat sd = new SimpleDateFormat("yyyy-MM-dd'T'hh:mm:ssZ");
    return sd.format(d);
  }
}
