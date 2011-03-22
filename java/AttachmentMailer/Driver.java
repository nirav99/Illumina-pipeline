/**
 * Class to instantiate the class to send email
 */
import java.io.*;
import java.util.LinkedList;

/**
 * 
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class Driver
{
  public static void main(String[] args)
  {
	  parseParams(args);
  }
  
  private static void printUsage()
  {
    System.err.println("Program to send email with attachments. Multiple attachments are supported");
    System.err.println("Sender=value    Sender email address");
    System.err.println("Sub=value       Email subject");
    System.err.println("Body=value      Email body");
    System.err.println("Dest=value      Email destination. Multiple values supported");
    System.err.println("Attach=value    Attachment files. Multiples values supported");
  }
  
  private static void parseParams(String[] args)
  {
    boolean foundSender           = false;
    boolean foundDest             = false;
    boolean foundAttachment       = false;
    String sender                 = null;
    String subject                = null;
    String body                   = null;
    LinkedList<String>dest        = new LinkedList<String>();
    LinkedList<String>attachments = new LinkedList<String>();
    String temp;
    
    for(int i = 0; i < args.length; i++)
    {
      if(args[i].toLowerCase().startsWith("sender="))
      {
        sender = getValue(args[i]);
        
        if(sender != null && !sender.isEmpty())
					foundSender = true;
      }
      else
      if(args[i].toLowerCase().startsWith("sub"))
      {
        subject = getValue(args[i]);
      }
      else
      if(args[i].toLowerCase().startsWith("body"))
      {
        body = getValue(args[i]);
      }
      else
      if(args[i].toLowerCase().startsWith("dest"))
      {
        temp = getValue(args[i]);
        if(temp != null || !temp.isEmpty())
        {
          foundDest = true;
          dest.add(temp);
        }
      }
      else
      if(args[i].toLowerCase().startsWith("attach"))
      {
        temp = getValue(args[i]);
        if(temp != null || !temp.isEmpty())
        {
          File f = new File(temp);
          if(!f.exists())
          {
            System.err.println("Specified file " + temp + " does not exist");
            System.exit(-2);
          }
          foundAttachment = true;
          attachments.add(temp);
        }
      }
    }
    if(!foundSender || !foundDest || !foundAttachment)
    {

      System.err.println("Found sender = " + foundSender);
      System.err.println("Found dest   = " + foundDest);
      System.err.println("Found attach = " + foundAttachment);
      printUsage();
      System.exit(-1);
    }
    else
    {
      if(subject == null || subject.isEmpty())
      {
        subject = "Email with attachments";
      }
      if(body == null || body.isEmpty())
      {
        body = "See the attachments";
      }
      try
      {
        Email emailSender = new Email(attachments, dest, sender, subject, body);
        emailSender.sendMail();
      }
      catch(Exception e)
      {
        System.err.println(e.getMessage());
        e.printStackTrace();
        System.exit(-1);
      }
    }
  }
  
  private static String getValue(String nameValuePair)
  {
    int idx = nameValuePair.indexOf("=");
    
    if(idx < 0)
      return null;
    else
      return nameValuePair.substring(idx + 1);
  }
}
