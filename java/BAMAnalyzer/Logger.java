import java.io.*;

/**
 * Class to encapsulate different logger types
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public abstract class Logger
{
  protected BufferedWriter writer = null;
  
  public Logger(File logFile) throws Exception
  {
    writer = new BufferedWriter(new FileWriter(logFile));
  }
  
  abstract void logResult(ResultMetric rResult) throws IOException;
  abstract void closeFile();
}
