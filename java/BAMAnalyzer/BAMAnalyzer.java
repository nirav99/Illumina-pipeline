/**
 * Class to calculate alignment and various metrics for a BAM.
 */
import net.sf.samtools.*;
import net.sf.samtools.SAMFileReader.ValidationStringency;
import net.sf.picard.cmdline.*;
import net.sf.picard.io.IoUtil;
import java.io.File;
import java.io.*;
import org.w3c.dom.*;
import javax.xml.parsers.*;
import javax.xml.transform.*;
import javax.xml.transform.dom.*;
import javax.xml.transform.stream.*;

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
    long totalReads               = 0;     // Total Reads in BAM file
    InsertSizeCalculator insCalc  = null;  // Class to calculate insert size
    PairStatsCalculator pairCalc  = null;  // Calculate information of read pairs
    AlignmentCalculator alignCalc = null;  // Calculate alignment information
    QualPerPosCalculator qualCalc = null;  // Calculate avg. base quality per base position
    
    try
    {
      IoUtil.assertFileIsReadable(INPUT);
    
      SAMFileReader.setDefaultValidationStringency(ValidationStringency.SILENT);
      reader = new SAMFileReader(INPUT);
  
      DocumentBuilderFactory dbfac = DocumentBuilderFactory.newInstance();
      DocumentBuilder docBuilder = dbfac.newDocumentBuilder();
      Document doc = docBuilder.newDocument();
      Element root = doc.createElement("AnalysisMetrics");
      
      alignCalc = new AlignmentCalculator();
      insCalc   = new InsertSizeCalculator();
      pairCalc  = new PairStatsCalculator();
      qualCalc  = new QualPerPosCalculator();
      
      long startTime = System.currentTimeMillis();
    
      for(SAMRecord record : reader)
      {
        totalReads++;
      
        if(totalReads > 0 && totalReads % 1000000 == 0)
        {
          System.err.print("\r" + totalReads);
        }
        
        alignCalc.processRead(record);
        insCalc.processRead(record);
        pairCalc.processRead(record);
        qualCalc.processRead(record);
        
        if(STOP_AFTER > 0 && totalReads > STOP_AFTER)
          break;
      }
    
      long stopTime = System.currentTimeMillis();
    
      reader.close();
  
      System.out.println();
      System.out.println("Total Reads in File : " + totalReads);
      alignCalc.showResult();
      insCalc.showResult();
      pairCalc.showResult();
      System.out.format("%nComputation Time      : %.3f sec%n%n", (stopTime - startTime)/1000.0);
      qualCalc.showResult();
      
      root.appendChild(alignCalc.toXML(doc));
      root.appendChild(insCalc.toXML(doc));
      root.appendChild(pairCalc.toXML(doc));
      doc.appendChild(root);
      
      TransformerFactory transfac = TransformerFactory.newInstance();
      Transformer trans = transfac.newTransformer();
      trans.setOutputProperty(OutputKeys.OMIT_XML_DECLARATION, "no");
      trans.setOutputProperty(OutputKeys.INDENT, "yes");
      StringWriter sw = new StringWriter();
      StreamResult result = new StreamResult(sw);
      DOMSource source = new DOMSource(doc);
      trans.transform(source, result);
      String xmlString = sw.toString();
      
      BufferedWriter writer = new BufferedWriter(new FileWriter(new File("BAMAnalysisInfo.xml")));
      writer.write(xmlString);
      writer.close();
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
