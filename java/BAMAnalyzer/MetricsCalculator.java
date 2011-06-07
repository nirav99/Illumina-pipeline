import net.sf.samtools.*;
import org.w3c.dom.*;

/**
 * Interface to represent different metrics calculation
 */

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public interface MetricsCalculator
{
  public void processRead(SAMRecord record); // Process next read
  public void showResult();                  // Display results
  public Element toXML(Document doc);        // XML element to write XML file
  public String toString();                  // String to display or log to file
}
