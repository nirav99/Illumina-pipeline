import java.io.File;
import java.io.*;
import org.w3c.dom.*;
import javax.xml.parsers.*;
import javax.xml.transform.*;
import javax.xml.transform.dom.*;
import javax.xml.transform.stream.*;

/**
 * Class encapsulating XML Logger
 */

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class XmlLogger extends Logger
{
  private Document doc = null;
  private Element root = null;
  
  public XmlLogger(File logFile) throws Exception
  {
    super(logFile);
    DocumentBuilderFactory dbfac = DocumentBuilderFactory.newInstance();
    DocumentBuilder docBuilder = dbfac.newDocumentBuilder();
    doc = docBuilder.newDocument();
    root = doc.createElement("AnalysisMetrics");
  }

  @Override
  void logResult(ResultMetric rResult) throws IOException
  {
    Element childElement = rResult.toXML(doc);
    
    if(childElement != null)
      root.appendChild(childElement);
  }
  
  @Override
  void closeFile()
  {
    try
    {
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
      writer.write(xmlString);
      writer.close();
    }
    catch(Exception e)
    {
      System.out.println(e.getMessage());
      e.printStackTrace();
    }
  }
}
