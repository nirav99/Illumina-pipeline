/**
 * Class encapsulating command line parameters
 */
import java.util.*;
import java.io.*;

/**
 * @author niravs
 *
 */
public class CmdParams
{
  String tempDir;       // Directory to store temporary files
  String inputFiles[];  // Names of input sequence files
  AnalysisMode mode;    // Analysis mode - fragment or paired
  boolean isInputValid; // If input is validated
  boolean detectAdaptors; // To detect for adaptor sequences
//  String adaptorFile;   // Name of file containing adaptor sequences  

  /**
   * Class constructor
   * @param args
   */
  public CmdParams(String args[])
  {
    tempDir     = null;
    inputFiles  = null;
//    adaptorFile = null;
    detectAdaptors = false; 

    isInputValid = validateInput(args);
    if(false == isInputValid)
    {
      printUsage();
      System.exit(-1);
    }
  }
  
  /**
   * Method to describe usage
   */
  private void printUsage()
  {
    System.out.println("");
    System.out.println("Usage :");
    System.out.println("AnalysisMode=Value TmpDir=Value Input=Value...");
 //   System.out.println("AdaptorFile=Value");
    System.out.println("  AnalysisMode : Fragment, Paired");
    System.out.println("  TmpDir       : To store intermediate files");
    System.out.println("  Input        : Sequence file to analyze");
    System.out.println("  DetectAdaptor: true - look for adaptor sequence");
    System.out.println("                 false - default");
//    System.out.println("  AdaptorFile  : Sequence of Adaptor Strings");
//    System.out.println("                 [Optional]");
  }

  /**
   * Method to validate the input parameters
   */ 
  private boolean validateInput(String args[])
  {
    boolean analysisModeFound = false;
    boolean tempDirFound      = false;
    boolean inputFileFound    = false;

    String param = null;
    String value = null;
    int idx      = 0;

    Vector<String> fileList = new Vector<String>();

    if(args.length < 3)
    {
      return false;
    }

    for(int i = 0; i < args.length; i++)
    {
      param = null;
      value = null;

      idx =  args[i].indexOf("=");
      
      if(idx < 0)
      {
        return false;
      }
      else
      {
        param = args[i].substring(0, idx);
        value = args[i].substring(idx + 1, args[i].length());
      }      

      // Validate Analysis Mode
      if(param.equalsIgnoreCase("analysismode"))
      {
        analysisModeFound = true;
        if(value.equalsIgnoreCase("paired"))
          mode = AnalysisMode.PAIRED;
        else
        if(value.equalsIgnoreCase("fragment"))
          mode = AnalysisMode.FRAGMENT;
        else
          return false;
      }

      // Validate Temp Dir 
      if(param.equalsIgnoreCase("tmpdir"))
      {
        tempDirFound = true;
        if(value == null || value.equals(""))
          return false;
        File f = new File(value);

        if(!f.isDirectory() || !f.canWrite())
        {
          System.err.println("Temp Dir : " + tempDir + " does not exist");
          System.err.println("             or does not have write permission");
          return false;
        }
        else
        {
          tempDir = value;
        }
      }
      // Validate that Input files are present
      if(param.equalsIgnoreCase("input"))
      {
        inputFileFound = true;
        
        if(value == null || value.equals(""))
          return false;
        
        File f = new File(value);

        if(!f.exists() || !f.canRead())
        {
          System.err.println("Cannot read input file : " + value);
          return false;
        }
        else
        {
          fileList.add(value);
        }
      }
      if(param.equalsIgnoreCase("detectadaptor"))
      {
        if(value == null || value.equals(""))
          return false;
        if(value.equalsIgnoreCase("true"))
          detectAdaptors = true;
      }
/*
      if(param.equalsIgnoreCase("adaptorfile"))
      {
        if(value == null || value.equals(""))
          return false;

        File f = new File(value);

        if(!f.exists() || !f.canRead())
        {
          System.err.println("Cannot read adaptor file : " + value);
          return false;
        }
        else
        {
          adaptorFile = value;
        }
      }
*/
    }
    if(!tempDirFound || !inputFileFound || !analysisModeFound)
      return false;

    if((mode == AnalysisMode.PAIRED) && ((fileList.size() % 2) != 0))  
    {
      System.err.println("For a paired mode, specify pairs input files");
      return false;
    }

    // All is valid - copy file names to array
    inputFiles = new String[fileList.size()];
    for(int i = 0; i < fileList.size(); i++)
    {
      inputFiles[i] = fileList.elementAt(i); 
    }
    return true;
  }
}
