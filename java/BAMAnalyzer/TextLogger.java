/**
 * Logger class to write the results in the text file format
 */
import java.io.*;
import java.util.*;

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class TextLogger extends Logger
{
  public TextLogger(File logFile) throws Exception
  {
    super(logFile);
  }
  
  @Override
  void logResult(ResultMetric rResult) throws IOException
  {
    writer.write(rResult.toString());
    writer.newLine();
  }

  @Override
  void closeFile()
  {
    try
    {
      writer.close();
    }
    catch(Exception e)
    {
      System.out.println(e.getMessage());
      e.printStackTrace();
    }
  }
}
