import net.sf.samtools.*;

/**
 * Interface to represent different metrics calculation
 */

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public interface MetricsCalculator
{
  public void processRead(SAMRecord record);  // Process next read
  public void showResult();                   // Display results
}
