import java.io.*;

/**
 * Two different plot styles, line and bars
 */
enum PlotStyle
{
  LINE,
  BAR
}

/**
 * Class to generate a plot using GNUPlot.
 * GNUPlot must be part of the user's PATH environment variable.
 */
public class Plot
{
  private String outputFile = null; // File name of plot
  private String plotTitle  = null; // Title of plot
  private String xLabel     = null; // Label of X-axis
  private String yLabel     = null; // Label of Y-axis

  private double xData[]    = null; // Data for X-axis
  private double y2Data[]   = null; // Data for Y-axis another series
  private double yData[]    = null; // Data for Y-axis

  private String series1    = null; // Name of series one
  private String series2    = null; // Name of series two

  // Configuration file for GNUPlot
  private String configFile = null;
  private File tempConfFile = null;

  // Data file for GNUPlot
  private String dataFile   = null;
  private File tempDataFile = null;

  // Scale values to use for the graph
  private double minXScale  = 0;
  private double maxXScale  = 0;
  private double minYScale  = 0;
  private double maxYScale  = 0;

  // Default plot style is LINE
  private static PlotStyle style = PlotStyle.LINE;

  /**
   * Class constructor for to plot a graph with dual series
   */
  public Plot(String outputFile, String plotTitle, String xLabel, String yLabel,
              String series1Name, String series2Name, double xData[],
              double yData[], double y2Data[]) throws Exception
  {
    this.series1 = series1Name;
    this.series2 = series2Name;
    constructorHelper(outputFile, plotTitle, xLabel, yLabel, xData, yData,
                      y2Data);
  }

  /**
   * Class constructor to plot a graph with one series
   */
  public Plot(String outputFile, String plotTitle, String xLabel,
              String yLabel, String seriesName, double xData[], double yData[])
              throws Exception
  {
    this.series1 = seriesName;
    constructorHelper(outputFile, plotTitle, xLabel, yLabel, xData, yData, null);
  }

  /**
   * Method to set the plot style
   */
  public static void setPlotStyle(PlotStyle ps)
  {
    style = ps;
  }

  /**
   * Private helper method for the overloaded constructors
   */
  private void constructorHelper(String outputFile, String plotTitle,
               String xLabel, String yLabel, double xData[], double yData[],
               double y2Data[]) throws Exception
  {
    this.outputFile = outputFile;
    this.plotTitle  = plotTitle;
    this.xLabel     = xLabel;
    this.yLabel     = yLabel;
    this.xData      = xData;
    this.y2Data     = y2Data;
    this.yData      = yData;

    tempDataFile =  new File(outputFile + ".dat");
    dataFile = tempDataFile.getName();

    System.err.println("Data file name : " + dataFile);
    tempConfFile = new File(outputFile + ".tmp");

    configFile = tempConfFile.getName();

    System.err.println("Plot Style : " + style.toString());
  }

  public void setXScale(double minValue, double maxValue)
  {
    minXScale = minValue;
    maxXScale = maxValue;
  }

  public void setYScale(double minValue, double maxValue)
  {
    minYScale = minValue;
    maxYScale = maxValue;
  }

  /**
   * Helper method to write GNU plot configuration file
   */
  private void writeGNUPlotConfigFile() throws Exception
  { 
    BufferedWriter writer = new BufferedWriter(new FileWriter(tempConfFile));
    writer.write("set terminal png");
    writer.newLine();
    writer.write("set output \"" + outputFile + "\"");
    writer.newLine();
    writer.write("set title \"" + plotTitle + "\"");
    writer.newLine();
    writer.write("set xlabel \"" + xLabel + "\"");
    writer.newLine();
    writer.write("set ylabel \"" + yLabel + "\"");
    writer.newLine();
    // Check if we need to use custom scale
    // TODO:

    String ps = null;

    if(style == PlotStyle.LINE)
      ps = "line";
    else
    if(style == PlotStyle.BAR)
      ps = "boxes";

    if(y2Data == null)
    {
      writer.write("plot \"" + dataFile + "\" using 1:2 title \'" + series1 +
                   "\' with " + ps);
    }
    else
    {
      writer.write("plot \"" + dataFile + "\" using 1:2 title \'" + series1 + 
                   "\'  with " + ps + ", \"" + dataFile + "\" using 1:3 title \'" + 
                   series2 + "\' with " + ps);
    }
    writer.newLine();
    writer.close();
  }

  /**
   * Helper method to write GNU plot data file
   */
  private void writeGNUPlotDataFile() throws Exception
  {
    BufferedWriter writer = new BufferedWriter(new FileWriter(tempDataFile));
    System.err.println("Writing data");
    for(int i = 0; i < xData.length; i++)
    {
      writer.write(xData[i] + "\t" + yData[i]);
      if(y2Data != null)
      {
        writer.write("\t" + y2Data[i]);
      }
      writer.newLine();
    }
    writer.close();
  }

  /**
   * Method to plot the graph and save in a file specified by outputFile
   */
  public void plotGraph() throws Exception
  {
    writeGNUPlotDataFile();
    writeGNUPlotConfigFile();
    Thread.sleep(30);

    Process p = Runtime.getRuntime().exec("gnuplot " + configFile);
    p.waitFor();
    System.err.println("Return Value of GNUPlot Process : " + p.exitValue());
    // Delete the temporary data and configuration files
    System.err.println("Deleting temp GNUPlot files");
    tempDataFile.delete();
    tempConfFile.delete();
    System.err.println("Deleted temp files");
  }
}
