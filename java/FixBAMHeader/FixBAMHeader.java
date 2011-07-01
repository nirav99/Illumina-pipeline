/**
 * Class to fix various header fields in a BAM/SAM file
 */

import net.sf.picard.cmdline.CommandLineProgram;
import net.sf.picard.cmdline.Option;
import net.sf.picard.cmdline.StandardOptionDefinitions;
import net.sf.picard.cmdline.Usage;
import net.sf.picard.io.IoUtil;
import net.sf.samtools.*;
import net.sf.samtools.util.RuntimeIOException;

import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.ListIterator;
/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class FixBAMHeader extends CommandLineProgram
{
	  @Usage
    public String USAGE = getStandardUsagePreamble() + "Read a SAM/BAM file and fix existing header fields." +
                          " It can add/modify sample, library and PU fields in an existing RG tag. If the file" +
                          " does not have RG tag, it creates a new RG tag with ID zero, adds specified attributes" +
                          " to it, and adds RG field to each read. It can add reference name attribute to SQ tags" +
                          " in the header. RG field attributes cannot be added or modified when the input file" +
                          " has more than one RG tags.";
	
	  @Option(shortName = StandardOptionDefinitions.INPUT_SHORT_NAME, doc = "Input SAM/BAM to be cleaned.")
    public File INPUT;

    @Option(shortName = StandardOptionDefinitions.OUTPUT_SHORT_NAME, optional=true,
            doc = "Where to write cleaned SAM/BAM. If not specified, replaces original input file.")
    public File OUTPUT;
    
    @Option(shortName = "S", optional=true, doc = "Sample name under RG tag")
    public String SAMPLE;
    
    @Option(shortName = "L", optional=true, doc = "Library name under RG tag")
    public String LIBRARY;
    
    @Option(shortName = "PU", optional=true, doc = "Platform unit (PU) field under RG tag")
    public String PLATFORMUNIT;
    
    @Option(shortName = "PL", optional=true, doc= "Platform (PL) field under RG tag")
    public String PLATFORM;
    
    @Option(shortName = "CN", optional=true, doc = "Center name (CN) field under RG tag")
    public String CENTERNAME;
    
    @Option(shortName = "R", optional=true, 
            doc = "Reference path. Sets the specified reference path as UR field in SQ tags. No validation is currently done.")
    public String REFERENCEPATH;
    
    @Option(shortName = "AS", optional=true, doc = "Genome assembly identifier (AS) field in SQ tags")
    public String GENOMEASSEMBLY;
    
    private boolean rgTagAdded = false; // Whether RG tag was added
    private String rgID = "0";          // Default RG tag ID
  
  /**
   * @param args
   */
  public static void main(String[] args)
  {
    new FixBAMHeader().instanceMainWithExit(args);
  }

  @Override
  protected int doWork()
  {
	  IoUtil.assertFileIsReadable(INPUT);
	  long numReadsProcessed = 0;
	
    if(OUTPUT != null) OUTPUT = OUTPUT.getAbsoluteFile();
    final boolean differentOutputFile = OUTPUT != null;
    
    if(differentOutputFile) 
      IoUtil.assertFileIsWritable(OUTPUT);
    else
      createTempFile();
    
    SAMFileReader.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);
    SAMFileReader reader = new SAMFileReader(INPUT);
    
    SAMFileHeader header = reader.getFileHeader();
    header = fixHeader(header);
    SAMFileWriter writer = new SAMFileWriterFactory().makeSAMOrBAMWriter(header, true, OUTPUT);
    
    SAMRecordIterator iter = reader.iterator();
    SAMRecord record = null;
    while(iter.hasNext())
    {
      numReadsProcessed++;
      if(numReadsProcessed % 1000000 == 0)
      {
        System.err.print("Processed : " + numReadsProcessed + " reads\r");
      }
      record = iter.next();
      
      if(rgTagAdded)
        record.setAttribute("RG", rgID);
      
      writer.addAlignment(record);
      record = null;
    }
    writer.close();
    reader.close();
    iter.close();
    
    if(differentOutputFile) return 0;
    else return replaceInputFile();
  }
  
  /**
   * Create a temp file for writing if original file is to be replaced.
   */
  protected void createTempFile()
  {
    final File inputFile = INPUT.getAbsoluteFile();
    final File inputDir  = inputFile.getParentFile().getAbsoluteFile();
	    
    try
    {
      IoUtil.assertFileIsWritable(inputFile);
      IoUtil.assertDirectoryIsWritable(inputDir);
      OUTPUT = File.createTempFile(inputFile.getName()+ "_being_fixed", ".bam", inputDir);
    }
    catch(IOException ioe)
    {
      throw new RuntimeIOException("Could not create tmp file in " + inputDir.getAbsolutePath());
    }
  }
  
  /**
   * Helper method to fix the header based on the new parameters specified
   */
  protected SAMFileHeader fixHeader(SAMFileHeader header)
  {
    List<SAMReadGroupRecord> rgList = header.getReadGroups();
    
    if((SAMPLE != null || LIBRARY != null || PLATFORMUNIT != null || CENTERNAME != null || PLATFORM != null)
        && rgList.size() > 1)
    {
      System.err.println("Error : RG tag fields cannot be set for a SAM/BAM file with more than one RG tag");
      System.exit(-1);
    }
    else
    if(rgList.size() == 0)
    {
      if(SAMPLE != null)
      {
        SAMReadGroupRecord rgRecord = new SAMReadGroupRecord(rgID);
        rgRecord.setSample(SAMPLE);
        header.addReadGroup(rgRecord);
        rgList = header.getReadGroups();
        rgTagAdded = true;
      }
      else
      if(LIBRARY != null || PLATFORMUNIT != null || CENTERNAME != null || PLATFORM != null)
      {
        System.err.println("Error: SAMPLE MUST be specified because the input file does not have any RG tag");
        System.exit(-1);
      }
    }
 
    if(SAMPLE != null)
      rgList.get(0).setSample(SAMPLE);
    if(LIBRARY != null)
      rgList.get(0).setLibrary(LIBRARY);
    if(PLATFORMUNIT != null)
      rgList.get(0).setPlatformUnit(PLATFORMUNIT);
    if(CENTERNAME != null)
      rgList.get(0).setSequencingCenter(CENTERNAME);
    if(PLATFORM != null)
      rgList.get(0).setPlatform(PLATFORM);
    
    header.setReadGroups(rgList);
    
    if(REFERENCEPATH != null || GENOMEASSEMBLY != null)
    {
      SAMSequenceDictionary seqDict        = header.getSequenceDictionary();
      List<SAMSequenceRecord> seqList      = seqDict.getSequences();
      ListIterator<SAMSequenceRecord> iter = seqList.listIterator();
      
      while(iter.hasNext())
      {
        SAMSequenceRecord rec = iter.next();
        
        if(REFERENCEPATH != null)
          rec.setAttribute("UR", REFERENCEPATH);
        if(GENOMEASSEMBLY != null)
          rec.setAssembly(GENOMEASSEMBLY);
      }
    }
    return header;
  }
  
  /**
   * Method to replace the input file if required
   * @return
   */
  protected int replaceInputFile()
  {
    final File inputFile = INPUT.getAbsoluteFile();
    final File oldFile = new File(inputFile.getParentFile(), inputFile.getName() + ".old");
    
    if(!oldFile.exists() && inputFile.renameTo(oldFile))
    {
      if(OUTPUT.renameTo(inputFile))
      {
        if(!oldFile.delete())
        {
          System.err.println("Could not delete old file : " + oldFile.getAbsolutePath());
          return 1;
        }
      }
      else
      {
        System.err.println("Could not move temp file to : " + inputFile.getAbsolutePath());
        System.err.println("Input file preserved as : " + oldFile.getAbsolutePath());
        System.err.println("New file preserved as : " + OUTPUT.getAbsolutePath());
        return 1;
      }
    }
    else
    {
      System.err.println("Could not move input file : " + inputFile.getAbsolutePath());
      System.err.println("New file preserved as : " + OUTPUT.getAbsolutePath());
      return 1;
    }
    return 0;
  }
}
