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

/**
 * Class to calculate insert size metrics
 */
import net.sf.picard.sam.SamPairUtil.PairOrientation;
import net.sf.samtools.*;
import net.sf.picard.sam.*;

/**
 * @author niravs
 * Class to calculate insert size. Insert size values are shown only for the 
 * orientation that is at least 10% of the total number of pairs.
 */
public class InsertSizeCalculator
{
  private InsertSizeMetrics frMetrics;     // Metrics for read pairs having f->r
                                           // orientation
  private InsertSizeMetrics rfMetrics;     // Metrics for read pairs having r->f
                                           // orientation
  private InsertSizeMetrics tandemMetrics; // Metrics for read pairs having
                                           // tandem orientation
  private int totalPairs = 0;              // Total pairs encountered so far
  
  /**
   * Class constructor
   */
  public InsertSizeCalculator()
  {
    frMetrics     = new InsertSizeMetrics(PairOrientation.FR);
    rfMetrics     = new InsertSizeMetrics(PairOrientation.RF);
    tandemMetrics = new InsertSizeMetrics(PairOrientation.TANDEM);
  }
  
  /**
   * Public method to process a record for insert size calculations
   * @param record - SAMRecord
   */
  public void calculateInsertSize(SAMRecord record)
  {
    if (!record.getReadPairedFlag() ||
         record.getReadUnmappedFlag() ||
         record.getMateUnmappedFlag() ||
         record.getFirstOfPairFlag() ||
         record.getNotPrimaryAlignmentFlag() ||
         record.getDuplicateReadFlag() ||
         record.getInferredInsertSize() == 0)
      return;
    
    totalPairs++;
    
    int insertSize = Math.abs(record.getInferredInsertSize());
    PairOrientation orientation = SamPairUtil.getPairOrientation(record);
    
    if(orientation == PairOrientation.FR)
      frMetrics.addInsertSize(insertSize);
    else
    if(orientation == PairOrientation.RF)
      rfMetrics.addInsertSize(insertSize);
    else
      tandemMetrics.addInsertSize(insertSize);
  }
  
  /**
   * Method to display insert size metrics calculations
   */
  public void showResult()
  {
    if(totalPairs <= 0)
    {
      return;
    }

    System.out.println();
    System.out.println("Insert Size Calculations");
    System.out.println();
    System.out.println("Total Pairs : " + totalPairs);
    System.out.println();

	  if(frMetrics.getTotalPairs()  > totalPairs * 0.1)
	  {
      frMetrics.showResult();
      System.out.println();
	  }
    
	  if(rfMetrics.getTotalPairs() > totalPairs * 0.1)
	  {
      rfMetrics.showResult();
      System.out.println();
	  }
    
    if(tandemMetrics.getTotalPairs() > totalPairs * 0.1)
    {
      tandemMetrics.showResult();
      System.out.println();
    }
  }
}
