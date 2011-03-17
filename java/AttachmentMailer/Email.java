import java.util.*; 
import javax.mail.*; 
import javax.mail.internet.*; 
import javax.activation.*;
import java.util.LinkedList;

/**
 * Class to send email with attachments
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class Email
{
  private LinkedList<String> attachmentFiles = null; // List of files to attach
  private LinkedList<String> destAddresses   = null; // List of email destinations
  private String senderEmail                 = null; // Who is sending email
  private String emailSubject                = null; // Email subject
  private String emailBody                   = null; // Text of email
  private String emailHost                   = null;
  
  public Email(LinkedList<String> attachFiles, LinkedList<String> dest,
               String sender, String subject, String body)
  {
    this.attachmentFiles = attachFiles;
    this.destAddresses   = dest;
    this.senderEmail     = sender;
    this.emailSubject    = subject;
    this.emailBody       = body;
    this.emailHost       = "smtp.bcm.tmc.edu";
  }
  
  public void sendMail() throws Exception
  {
    Properties props = System.getProperties();
    props.put("mail.smtp.host", emailHost);
	   
    Session session = Session.getInstance(props, null);
			   
    Message message = new MimeMessage(session);
    message.setFrom(new InternetAddress(senderEmail));

    InternetAddress[] toAddress = new InternetAddress[destAddresses.size()];

    for (int i = 0; i < destAddresses.size(); i++)
    {
      toAddress[i] = new InternetAddress(destAddresses.get(i));
    }
    
    message.setRecipients(Message.RecipientType.TO, toAddress);    
    message.setSubject(emailSubject.toString());
    BodyPart messageBodyPart = new MimeBodyPart();

    if(emailBody.equals(""))
    {
      messageBodyPart.setText("Please see the attached file");
    }
    else
    {
      messageBodyPart.setText(emailBody);
    }
    
    Multipart multipart = new MimeMultipart();
    multipart.addBodyPart(messageBodyPart);
    
    for(int i = 0; i < attachmentFiles.size(); i++)
    {
      messageBodyPart = new MimeBodyPart();
      DataSource source = new FileDataSource(attachmentFiles.get(i));
      messageBodyPart.setDataHandler(new DataHandler(source));
      messageBodyPart.setFileName(attachmentFiles.get(i));
      multipart.addBodyPart(messageBodyPart);
    }
    
    message.setContent(multipart);
    try
    {
      Transport.send(message);
    }
    catch(Exception e)
    {
      System.err.println(e.toString());
    }
  }
}
