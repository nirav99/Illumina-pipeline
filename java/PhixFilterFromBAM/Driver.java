import java.util.*;
import java.io.*;

/**
 * Class to drive the PhixFilter
 */

/**
 * @author niravs
 *
 */
public class Driver
{
  /**
   * @param args
   */
  public static void main(String[] args) 
  {
    try
    {
      CmdParams cmdParams = new CmdParams(args);
      PhixFilter filter   = new PhixFilter(cmdParams.getInputFile(),
    		                               cmdParams.getOutputFile());
      filter.filterPhixReads();
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
    }
  }
}
