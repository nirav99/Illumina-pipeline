/**
 * @author niravs
 *
 */
public class InputParameters
{
  private String inputFile   = null; // BAM file to add RG tag to
  private String outputFile  = null; // BAM file to write to
  private String readGroupID = null; // Read group Id
  private String sampleID    = null; // Sample ID for RG tag
  private String libraryName = null; // Library name (LB) tag
  private String platform    = null; // Platform (PL) tag
  private String prgName     = null; // ID of PG header
  private String prgVer      = null; // VN field of PG header
  private String center      = "BCM";// Name of the sequencing center
  private String pUnit       = null; // Platform unit (PU) tag
  
  public InputParameters(String args[])
  {
    if(false == validateArgs(args))
    {
      printUsage();
      System.exit(-1);
    }
  }
  
  private void printUsage()
  {
    System.err.println("Usage:");
    System.err.print("  java -jar AddRGToBAM.jar Input=value Output=value");
    System.err.println(" RGTag=value SampleID=value");
    System.err.println("    Input         - Input BAM to add RG tag to");
    System.err.println("    Output        - Name of output file with RG tag added");
    System.err.println("    RGTag         - Value of RG tag. Default : 0");
    System.err.println("    SampleID      - Sample name, Default : unknown");
    System.err.println("    Library       - Library name (optional)");
    System.err.println("    Platform      - Platform name (PL tag) (optional)");
    System.err.println("    PlatformUnit  - Platform Unit (PU tag) (optional)");
    System.err.println("    Center        - Name of the sequencing center, default BCM");
    System.err.println("    Program       - Mapper name (optional)");
    System.err.println("    Version       - Mapper Version (optional)");
  }
  
  private boolean validateArgs(String args[])
  {
    String param;
    String value;
    
    boolean inputFileFound = false;
    boolean outputFileFound = false;
    
    int idx = -1;
    
    for(int i = 0; i < args.length; i++)
    {
      idx =  args[i].indexOf("=");
      
      if(idx < 0)
      {
        return false;
      }
      param = args[i].substring(0, idx);
      value = args[i].substring(idx + 1, args[i].length());
      
      if(param.equalsIgnoreCase("Input") || param.equalsIgnoreCase("I"))
      {
        inputFileFound = true;
        inputFile = value;
      }
      else
      if(param.equalsIgnoreCase("Output") || param.equalsIgnoreCase("O"))
      {
        outputFileFound = true;
        outputFile = value;
      }
      else
      if(param.equalsIgnoreCase("RGTag"))
      {
        readGroupID = value;
      }
      else
      if(param.equalsIgnoreCase("SampleID"))
      {
        sampleID = value;
      }
      else
      if(param.equalsIgnoreCase("library"))
      {
        libraryName = value;
      }
      else
      if(param.equalsIgnoreCase("platform"))
      {
        platform = value;
      }
      else
      if(param.equalsIgnoreCase("platformunit"))
      {
        pUnit = value;
      }
      else
      if(param.equalsIgnoreCase("program"))
      {
        prgName = value;
      }
      else
      if(param.equalsIgnoreCase("version"))
      {
        prgVer = value;
      }
      else
      if(param.equalsIgnoreCase("center"))
      {
        center = value; 
      }
    }
    
    if(inputFileFound && outputFileFound)
    {
      // Input is valid - fix missing fields if applicable
      if(readGroupID == null)
      {
        readGroupID = "0";
      }
      if(sampleID == null)
      {
        sampleID = "unknown";
      }
      if(libraryName == null)
      {
        libraryName = "";
      }
      if(platform == null)
      {
        platform = "";
      }
      return true;
    }
    else
      return false;
  }
  
  public String getInputFile()
  {
    return inputFile;
  }
  
  public String getOutputFile()
  {
    return outputFile;
  }
  
  public String getReadGroupID()
  {
    return readGroupID;
  }
  
  public String getSampleID()
  {
    return sampleID;
  }

  public String getLibraryName()
  {
    return libraryName;
  }

  public String getPlatformName()
  {
    return platform;
  }

  public String getPlatformUnitName()
  {
    return pUnit;
  }
  public String getProgramName()
  {
    return prgName;
  }

  public String getProgramVersion()
  {
    return prgVer;
  }

  public String getCenterName()
  {
    return center;
  }
}

