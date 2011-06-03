import java.util.TreeMap;
import net.sf.picard.sam.SamPairUtil.PairOrientation;
import java.io.*;
import org.w3c.dom.*;

/**
 * Class to encapsulate insert size metrics
 */

/**
 * @author Nirav Shah niravs@bcm.edu
 * Class encapsulating insert size metrics
 */
public class InsertSizeMetrics
{
  private PairOrientation orientation;    // Orientation of the read pair
  private InsertSizeBin insertBin = null; // To hold insert sizes
  private double percentReadPairs = 0;    // Percentage of read pairs for this orientation
  /**
   * Class constructor
   * @param orient - Orientation of the pair 
   */ 
  public InsertSizeMetrics(PairOrientation orient)
  {
    this.orientation = orient;
    insertBin = new InsertSizeBin();
  }
 
  /**
   * Method to remember the insert size for the current read
   * @param insertSize - integer corresponding to insert size for the read
   */ 
  public void addInsertSize(int insertSize)
  {
    insertBin.addInsertSize(insertSize);
  }

  /**
   * Display the insert size metrics
   */
  public void calculateResult()
  {
    insertBin.calculateStats();
    try
    {
      logInsertSizeDistribution();
      createDistributionChart();
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
    }
  }
  
  public void showResult(int totalMappedPairs)
  {
    if(getTotalPairs() <totalMappedPairs * 0.1)
      return;
    calculateResult();
    
    System.out.print("Pair Orientation   : ");

    if(orientation.equals(PairOrientation.FR))
      System.out.println("FR (5' --F-->     <--R-- 5')");
    else
    if(orientation.equals(PairOrientation.RF))
      System.out.println("RF (<--R-- 5'     5' --F-->)");
    else
      System.out.println("Tandem (Both on forward or reverse strands)");
    
    percentReadPairs = 1.0 * getTotalPairs() / totalMappedPairs * 100.0;
    
    System.out.println("Num. Read Pairs    : " + getTotalPairs());
    System.out.format("%% Read Pairs       : %.2f %%\n", percentReadPairs); 
    System.out.println("Median Insert Size : " + getMedianInsertSize());
    System.out.println("Mode Insert Size   : " + getModeInsertSize());
    System.out.println();
  }
  
  public Element toXML(Document doc)
  {
    Element rootElem = doc.createElement("InsertSizeResults");
    rootElem.setAttribute("PairOrientation", orientation.toString());
    rootElem.setAttribute("TotalPairs", String.valueOf(getTotalPairs()));
    rootElem.setAttribute("PercentPairs", String.valueOf(percentReadPairs));
    
    Element insertSizeInfoElem = doc.createElement("InsertSize");
    insertSizeInfoElem.setAttribute("MedianInsertSize", String.valueOf(getMedianInsertSize()));
    insertSizeInfoElem.setAttribute("ModeInsertSize", String.valueOf(getModeInsertSize()));
    rootElem.appendChild(insertSizeInfoElem);
    return rootElem;
  }
  
  /**
   * Returns total number of pairs for specified orientation
   * @return - total pairs
   */
  public int getTotalPairs()
  {
    return insertBin.getTotalPairs();
  }

  public int getMedianInsertSize()
  {
    return insertBin.getMedianInsertSize();
  }

  public int getModeInsertSize()
  {
    return insertBin.getModeInsertSize();
  } 

  public PairOrientation getPairOrientation()
  {
    return orientation;
  }
  
  /**
   * Log insert size distribution in a CSV
   */
  private void logInsertSizeDistribution() throws IOException
  {
    System.err.println("Logging time");
    String logFileName    = orientation.toString() + "_InsertSizeDist.csv";
    BufferedWriter writer = new BufferedWriter(new FileWriter(logFileName));
    
    int insertSizeArray[] = insertBin.getInsertSizeList();
    int numReads[]        = insertBin.getInsertSizeDistribution();
    
    for(int i = 0; i < insertSizeArray.length; i++)
    {
      writer.write(insertSizeArray[i] + "," + numReads[i]);
      writer.newLine();
    }
    writer.close();
  }

  /**
   * Plot the distribution of insert size using GNUPlot
   */
  private void createDistributionChart()
  {
    System.err.println("Drawing Plot Time");
    String outputFile = orientation.toString() + "_InsertSizeDist.png";

    double xAxis[] = new double[insertBin.getInsertSizeList().length];
    double yAxis[] = new double[insertBin.getInsertSizeList().length];
    
    for(int i = 0; i < xAxis.length; i++)
    {
      xAxis[i] = insertBin.getInsertSizeList()[i];
      yAxis[i] = insertBin.getInsertSizeDistribution()[i];
    }
    
    try
    {
      Plot p = new Plot(outputFile, "Insert Size Distribution", "Insert Size", 
		          "Number of Reads", orientation.toString() + "_Distribution",
		          xAxis, yAxis);
      p.plotGraph();
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
    }
  }
}
