import org.w3c.dom.Document;
import org.w3c.dom.Element;

import net.sf.samtools.SAMRecord;

/**
 * Class to calculate alignment metrics
 */

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class AlignmentCalculator implements MetricsCalculator
{
  private MismatchCounter mmCounter     = null;  // Count number of mismatches in a read
  private AlignmentResults read1Results = null;  // Mapping results for read1
  private AlignmentResults read2Results = null;  // Mapping results for read2
  private AlignmentResults fragResults  = null;  // Mapping results for unpaired reads

  /**
   * Default class constructor - initialize the metrics objects
   */
  public AlignmentCalculator()
  {
    mmCounter     = new MismatchCounter();
    read1Results  = new AlignmentResults("Read1", mmCounter);
    read2Results  = new AlignmentResults("Read2", mmCounter);
    fragResults   = new AlignmentResults("Fragment", mmCounter);
  }
  
  /* 
   * Process next read
   */
  @Override
  public void processRead(SAMRecord record)
  {
	try
	{
      if(record.getReadPairedFlag() && record.getFirstOfPairFlag())
        read1Results.processRead(record);
      else
      if(record.getReadPairedFlag() && record.getSecondOfPairFlag())
        read2Results.processRead(record);
      else
      if(!record.getReadPairedFlag())
        fragResults.processRead(record);	
	}
	catch(Exception e)
	{
	  System.out.println(e.getMessage());
	  e.printStackTrace();
	  System.exit(-1);
	}
  }

  /* 
   * Show the results
   */
  @Override
  public void showResult()
  {
    read1Results.showAlignmentResults();
    read2Results.showAlignmentResults();
    fragResults.showAlignmentResults();
  }

  @Override
  public Element toXML(Document doc)
  {
    Element rootNode = doc.createElement("AlignmentMetrics");
    
    Element read1InfoNode = read1Results.toXML(doc);
    if(read1InfoNode != null)
      rootNode.appendChild(read1InfoNode);
    
    Element read2InfoNode = read2Results.toXML(doc);
    if(read2InfoNode != null)
      rootNode.appendChild(read2InfoNode);
    
    Element fragInfoNode  = fragResults.toXML(doc);
    if(fragInfoNode != null)
      rootNode.appendChild(fragInfoNode);
    
	return rootNode;
  }
}
