import java.io.*;

/**
 * Class to encapsulate command line parameters
 */

/**
 * @author niravs
 *
 */
public class CmdParams
{
  private String inputFileName  = null;
  private String outputFileName = null; 
  
  public CmdParams(String args[])
  {
    validateArgs(args);
  }
  
  public String getInputFile()
  {
    return inputFileName;
  }
  
  public String getOutputFile()
  {
    return outputFileName;
  }
  
  private void printUsage()
  {
    System.err.println("Usage : ");
    System.err.println("Input (I)  : Input BAM File Name");
    System.err.println("Output (O) : File to write filtered reads to.");
    System.err.println("             (Optional) - if absent, input file is overwritten");
  }
  
  private void validateArgs(String[] args)
  {
    String param = null;
    String value = null;
    int idx = 0;
    
    if(args.length < 1 || args.length > 2)
    {
      printUsage();
      System.exit(-1);
    }
    
    for(int i = 0; i < args.length; i++)
    {
      idx =  args[i].indexOf("=");

      if(idx < 0)
      {
        printUsage();
        System.exit(-2);
      }
      else
      {
        param = args[i].substring(0, idx);
        value = args[i].substring(idx + 1, args[i].length());
        
        if(param.equalsIgnoreCase("input") || param.equalsIgnoreCase("i"))
        {
          inputFileName = value;
        }
        if(param.equalsIgnoreCase("output") || param.equalsIgnoreCase("o"))
        {
          outputFileName = value;
        }
      }
    }
    if(inputFileName == null)
    {
      printUsage();
      System.exit(-3);
    }
    
    File f = new File(inputFileName);
    
    if(!f.exists() || !f.canRead())
    {
      System.err.println("Input File : " + inputFileName + " is not a regular file, or cannot be read");
      System.exit(-3);
    }
    
    if(outputFileName == null && !f.canWrite())
    {
      System.err.println("Specified input file cannot be written to");
      System.exit(-3);
    }
  }
}
