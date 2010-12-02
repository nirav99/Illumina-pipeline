/*
 * The MIT License
 *
 * Copyright (c) 2009 The Broad Institute
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import java.util.TreeMap;
import net.sf.picard.sam.SamPairUtil.PairOrientation;

/**
 * Class to encapsulate insert size metrics
 */

/**
 * @author niravs
 * Class encapsulating insert size metrics
 */
public class InsertSizeMetrics
{
  private PairOrientation orientation;  // Orientation of the read pair
  private int medianInsertSize  = 0;    // Median value of insert size
  private int modalInsertSize   = 0;    // Modal value of insert size
  private int totalPairs        = 0;    // Total pairs of records
  private double meanInsertSize = 0;    // Mean insert size
  
  private TreeMap<Integer, Integer> insertSizeList = null;

  /**
   * Class constructor
   * @param orient - Orientation of the pair 
   */ 
  public InsertSizeMetrics(PairOrientation orient)
  {
    this.orientation = orient;
    insertSizeList = new TreeMap<Integer, Integer>();
  }
 
  /**
   * Method to remember the insert size for the current read
   * @param insertSize - integer corresponding to insert size for the read
   */ 
  public void addInsertSize(int insertSize)
  {
    totalPairs++;
    
    Integer iSize = new Integer(insertSize); 
    if(insertSizeList.containsKey(iSize))
    {
      Integer val = insertSizeList.get(iSize);
      val++;
      insertSizeList.put(iSize, val);
      val = null;
    }
    else
    {
      insertSizeList.put(iSize, 0);
    }
    iSize = null;
  }
  
  /**
   * Returns total number of pairs for specified orientation
   * @return - total pairs
   */
  public int getTotalPairs()
  {
    return totalPairs;
  }
 
  /**
   * Calculate median insert size
   */ 
  private void findMedianInsertSize()
  {
    int medianIndex = totalPairs / 2;
    int numElements = 0;
    
    for(Integer key : insertSizeList.keySet())
    {
      numElements = numElements + insertSizeList.get(key).intValue();
      
      if(numElements > medianIndex)
      {
        medianInsertSize = key.intValue();
        break;
      }
      key = null;
    }
  }
 
  /**
   * Calculate mean insert size
   */ 
  private void findMeanInsertSize()
  {
    double sumInsertSize = 0;
    double numElem = 0;
    
    for(Integer key : insertSizeList.keySet())
    {
      numElem = numElem + insertSizeList.get(key).doubleValue();
      sumInsertSize = sumInsertSize + insertSizeList.get(key).doubleValue() *
                      key.doubleValue();
      key = null;
    }
    meanInsertSize = sumInsertSize / numElem;
  }

  /**
   * Calculate mode of the insert size
   */
  private void findModalInsertSize()
  {
    Integer modeInsert = insertSizeList.firstKey();
    Integer modeValue  = insertSizeList.get(modeInsert);

    for(Integer key : insertSizeList.keySet())
    {
      if(modeValue < insertSizeList.get(key))
      {
        modeInsert = key;
        modeValue  = insertSizeList.get(key);
      }
      key = null;
    }
    modalInsertSize = modeInsert.intValue();
  }

  /**
   * Display the insert size metrics
   */
  public void showResult()
  {
    System.err.println("Number of Elements in TreeMap : " + insertSizeList.size()); 

    System.out.print("Pair Orientation : ");
    if(orientation.equals(PairOrientation.FR))
      System.out.println("FR (5' --F-->     <--R-- 5')");
    else
    if(orientation.equals(PairOrientation.RF))
      System.out.println("RF (  <--R-- 5' 5' --F-->)");
    else
      System.out.println("Tandem (Both on forward or reverse strands)");
    
    findMedianInsertSize();
    findModalInsertSize();
    System.out.println("Num. Read Pairs    : " + totalPairs);
    System.out.println("Median Insert Size : " + medianInsertSize);
    System.out.println("Modal Insert Size  : " + modalInsertSize);
  }
}
