import java.util.ArrayList;
import java.util.List;
import org.w3c.dom.*;

/**
 * Class that encapsulates the metric results
 */

/**
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class ResultMetric
{
  private String metricName;        // Name of the metric
  private ArrayList<String>keys;    // List of keys  
  private ArrayList<String>vals;    // List of values
  private ArrayList<ResultMetric> nextMetrics;  // List of next metric objects
  
  /**
   * Class constructor
   */
  public ResultMetric()
  {
    metricName = null;
    keys = new ArrayList<String>();
    vals = new ArrayList<String>();
    nextMetrics = null;
  }
  
  public void setMetricName(String mName)
  {
    metricName = mName;
  }
  
  /**
   * Method to add key-value pair
   * @param key
   * @param value
   */
  public void addKeyValue(String key, String value)
  {
    keys.add(key);
    vals.add(value);
  }
  
  /**
   * Method to add children result metrics
   * @param next
   */
  public void addResultMetric(ResultMetric next)
  {
    if(nextMetrics == null)
       nextMetrics = new ArrayList<ResultMetric>();
    nextMetrics.add(next);
  }
  
  public String getMetricName()
  {
    return metricName;
  }
  
  public ArrayList<ResultMetric> getChildMetrics()
  {
    return nextMetrics;
  }
  
  public ArrayList<String> getKeys()
  {
    return keys;
  }
  
  public ArrayList<String> getValues()
  {
    return vals;
  }
  
  /**
   * Override the default java.object.toString to get string representation
   * of the result metric.
   */
  @Override  
  public String toString()
  {
    StringBuffer resultString = new StringBuffer();
    String newLine = "\r\n";
    
    resultString.append(newLine + metricName + newLine);
    
    if(keys != null && keys.size() > 0)
    {
      for(int i = 0; i < keys.size(); i++)
        resultString.append(keys.get(i) + " : " + vals.get(i) + newLine);
    }
    
    if(nextMetrics != null && nextMetrics.size() > 0)
    {
      for(int i = 0; i < nextMetrics.size(); i++)
        resultString = resultString.append(nextMetrics.get(i).toString());
    }
    return resultString.toString();
  }
  
  /**
   * Method to generate an XML element from the given ResultMetric object
   * @param doc
   * @return
   */
  public Element toXML(Document doc)
  {
    if(metricName == null || metricName.isEmpty())
      return null;
    
    Element rootElement = doc.createElement(metricName);
    
    if(keys != null && keys.size() > 0)
    {
      for(int i = 0; i < keys.size(); i++)
        rootElement.setAttribute(keys.get(i), vals.get(i));
    }
    
    if(nextMetrics != null && nextMetrics.size() > 0)
    {
      for(int i = 0; i < nextMetrics.size(); i++)
      {
        Element childElement = nextMetrics.get(i).toXML(doc);
        if(childElement != null)
          rootElement.appendChild(childElement);
      }
    }
    return rootElement;
  }
}
