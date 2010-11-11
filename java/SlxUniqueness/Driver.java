/**
 * Driver class to calculate duplicates
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
      CmdParams inputParams = new CmdParams(args);
      UniquenessCalc uc = new UniquenessCalc(inputParams);
      uc.process();
    }
    catch(Exception f)
    {
      System.err.println(f.getMessage());
      f.printStackTrace();
    }
  }
}

