/**
 * Class to filter reads mapping to phix from a BAM file
 */
import java.io.*;
import java.util.*;

import net.sf.samtools.*;
import net.sf.samtools.SAMFileReader.ValidationStringency;

/**
 * @author niravs
 *
 */
public class PhixFilter
{
  private long totalReads     = 0;     // Sum of all the reads in the BAM
  private long discardedReads = 0;     // Number of reads removed from BAM
  
  private SAMFileReader reader         = null; // To read a BAM
  private SAMFileWriter writer         = null; // To write a BAM
  private SAMFileHeader filteredHeader = null; // Filtered header
  
  private String inputName    = null;  // Name of the bam to filter
  private String outFileName  = null;  // Name of output file
  
  private boolean replaceInputFile = false; // Whether to over-write input file
  
  // Name of the phix chromosome
  private String phixContig  = "gi|9626372|ref|NC_001422.1|";
  
  //To remember reads that map to Phix
  private Hashtable<String, String> phixReads = null;
  
  /**
   * Class constructor
   * @param bamName
   */
  public PhixFilter(String bamName)
  {
    constructorHelper(bamName, null);
  }
  
  /**
   * Class constructor
   * @param bamName
   * @param outName
   */
  public PhixFilter(String bamName, String outName)
  {
	  constructorHelper(bamName, outName);
  }
  
  /**
   * Helper method for the overloaded constructors
   * @param inputFile
   * @param outputName
   */
  private void constructorHelper(String inputFile, String outputName)
  {
    this.inputName   = inputFile;
    this.outFileName = outputName;
    
    if(outputName == null || outputName.isEmpty())
    {
      this.outFileName = generateOutputName(inputName);
      System.out.println("Name of Temp. Output File : " + outFileName);
      replaceInputFile = true;
    }

    SAMFileReader.setDefaultValidationStringency(ValidationStringency.SILENT);
    reader = new SAMFileReader(new File(inputName));
	    
    phixReads = new Hashtable<String, String>();
    buildPhixReadsTable();
    File outputFile = new File(outFileName);
   
    // Create a new header for the output file without the contig to remove
    getFilteredHeader();

    System.out.println("Header created");
    writer = new SAMFileWriterFactory().makeSAMOrBAMWriter(filteredHeader, true, outputFile);
  }
  
  /**
   * Method to generate name for the temporary file
   * @param inputBAM
   * @return
   */
  private String generateOutputName(String inputBAM)
  {
    String temp = "";
    if(inputBAM.endsWith(".bam"))
      temp = inputBAM.replaceFirst(".bam", "_filtered.bam");
    else
    if(inputBAM.endsWith(".sam"))
      temp = inputBAM.replaceFirst(".sam", "_filtered.sam");
    return temp;
  }
  
  /**
   * Method to obtain reads that map to phix
   * @return
   * @throws Exception
   */
  public Hashtable<String, String> getPhixReads() throws Exception
  {
    return phixReads;
  }
  
  /**
   * Method to filter out phix reads from the BAM file
   */
  public void filterPhixReads() 
  {
    SAMRecord samRecord = null;
    System.out.println("Filtering started");
    
    // Index of reference in sequence dictionary where current read maps
    int refIdx  = -1;
    // Name of reference that current read maps to
    String refName = null;
    // Index of reference in sequence dictionary where mate of current read maps
    int mateIdx = -1; 
    // Name of reference where mate of the current read maps to
    String mateRefName = null;
    
    try
    {
      SAMRecordIterator it = reader.iterator();
 
      while(it.hasNext())
      {
        samRecord = it.next();
        totalReads++;
        
        if(totalReads % 1000000 == 0)
          System.err.print(totalReads + "\r");
 
        if(!phixReads.containsKey(samRecord.getReadName()))
        {
          mateRefName = samRecord.getMateReferenceName();
          refName     = samRecord.getReferenceName();
          
          refIdx  = -1;
          mateIdx = -1;
          
          samRecord.setHeader(filteredHeader);
          
          if(refName != null && !refName.isEmpty())
          {
            refIdx = filteredHeader.getSequenceIndex(refName);
            samRecord.setReferenceIndex(refIdx);
          }
          if(mateRefName != null && !mateRefName.isEmpty())
          {
            mateIdx = filteredHeader.getSequenceIndex(mateRefName);
            samRecord.setMateReferenceIndex(mateIdx);
          }
          writer.addAlignment(samRecord);
        }
        else
        {
          discardedReads++;
        }
        samRecord = null;
      }
      it.close();
      reader.close();
      writer.close();
      reader = null;
      writer = null;
    
      System.out.println("Total Reads   : " + totalReads);
      System.out.println("Phix Reads    : " + discardedReads);
      System.out.format("%% Reads Filtered : %.2f %%",  1.0 * discardedReads / totalReads * 100.0);
      System.out.println();
    
      if(replaceInputFile)
      {
        System.out.println("Replacing the original file");
        replaceFile();
        System.out.println("Phix filtering completed");
      }
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
   
      System.err.println("Num. Reads written to output : " + totalReads); 
      System.err.println("Read that caused Exception : " + samRecord.toString());  
      if(reader != null)
        reader.close();
      if(writer != null)
        writer.close();
    }
  }
  
  /**
   * Method to remember the names of the reads mapping to phix
   */
  private void buildPhixReadsTable()
  {
    SAMRecordIterator it = reader.iterator();
    SAMRecord samRecord = null;

    System.out.println("Building the hashtable of reads to discard");
    
    while(it.hasNext())
    {
      try
      {
        samRecord = it.next();
        if(!samRecord.getReadUnmappedFlag() && 
            samRecord.getReferenceName().equalsIgnoreCase(phixContig))
        {	  
          if(!phixReads.containsKey(samRecord.getReadName()))
          {
            phixReads.put(samRecord.getReadName(), "");
          }
        }
      }
      catch(Exception e)
      {
        System.err.println(e.getMessage());
        e.printStackTrace();
        if(samRecord != null)
        {	
          System.err.println("Read Name : " + samRecord.getReadName());
          System.err.println("Read : " + samRecord.toString());
        }
      }
    }
    it.close();
    System.out.println("Num. reads in hashtable = " + phixReads.size());
  }
  
  /**
   * Helper method to replace the input file with the filtered file
   */
  private void replaceFile()
  {
    File f1 = new File(inputName);
    File f2 = new File(outFileName);
    
    try
    {
      if(f1.exists() && f2.exists())
      {
        if(f1.delete())
        {
          f2.renameTo(f1);
        }
      }
    }
    catch(Exception e)
    {
      System.err.println("Error while renaming " + inputName);
      System.err.println(" Exception : " + e.getMessage());
    }
  }
  
  /**
   * Method to remove the phix contig from the sequence dictionary of the header
   */
  private void getFilteredHeader()
  {
    SAMFileHeader header = reader.getFileHeader().clone();
    SAMSequenceDictionary seqDict = header.getSequenceDictionary();
    
    SAMSequenceDictionary filteredSeqDict = new SAMSequenceDictionary();
    
    SAMSequenceRecord seqRecord = null;
    
    for(int i = 0; i < seqDict.size(); i++)
    {
      seqRecord = seqDict.getSequence(i);
      
      if(!seqRecord.getSequenceName().equals(phixContig))
      {
        filteredSeqDict.addSequence(seqRecord);
      }
      seqRecord = null;
    }
    
    filteredHeader = header;
    filteredHeader.setSequenceDictionary(filteredSeqDict);
  }
}
