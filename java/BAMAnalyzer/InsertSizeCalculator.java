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
 * @author Nirav Shah niravs@bcm.edu
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
  private int totalMappedPairs = 0;        // Total pairs where both reads are
                                           // mapped
  private int totalPairs = 0;              // Total pairs, irrespective of
                                           // whether mapping status of the reads  

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
    // On encountering a paired read for the second read, increment
    // total number of pairs
    if(record.getReadPairedFlag() && !record.getFirstOfPairFlag())
    {
       totalPairs++;
    }
    if (!record.getReadPairedFlag() ||
         record.getReadUnmappedFlag() ||
         record.getMateUnmappedFlag() ||
         record.getFirstOfPairFlag() ||
         record.getNotPrimaryAlignmentFlag() ||
         record.getDuplicateReadFlag() ||
         record.getInferredInsertSize() == 0)
      return;
    
    totalMappedPairs++;
    
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
    if(totalMappedPairs <= 0)
    {
      return;
    }

    System.out.println();
    System.out.println("Insert Size Calculations");
    System.out.println();
    System.out.println("Total Read Pairs : " + totalPairs);
    System.out.println();
    System.out.println("Pairs with Both Reads Mapped   : " + totalMappedPairs);
    System.out.format("%% Pairs with Both Reads Mapped : %.2f%%\n", 1.0 * totalMappedPairs / totalPairs * 100.0);
    System.out.println();

    if(frMetrics.getTotalPairs()  > totalMappedPairs * 0.1)
    {
      frMetrics.calculateResult();
      showResult(frMetrics);
    }
    
    if(rfMetrics.getTotalPairs() > totalMappedPairs * 0.1)
    {
      rfMetrics.calculateResult();
      showResult(rfMetrics);
    }
    
    if(tandemMetrics.getTotalPairs() > totalMappedPairs * 0.1)
    {
      tandemMetrics.calculateResult();
      showResult(tandemMetrics);
    }
  }

  /**
   * Display the result
   */
  private void showResult(InsertSizeMetrics metrics)
  {
    PairOrientation orientation = metrics.getPairOrientation();
  
    System.out.print("Pair Orientation : ");

    if(orientation.equals(PairOrientation.FR))
      System.out.println("FR (5' --F-->     <--R-- 5')");
    else
    if(orientation.equals(PairOrientation.RF))
      System.out.println("RF (<--R-- 5'     5' --F-->)");
    else
      System.out.println("Tandem (Both on forward or reverse strands)");

    System.out.println("Num. Read Pairs : " + metrics.getTotalPairs());
    System.out.format("%% Read Pairs   : %.2f %%\n", 1.0 * metrics.getTotalPairs() / totalPairs * 100.0); 
    System.out.println("Median Insert Size : " + metrics.getMedianInsertSize());
    System.out.println("Mode Insert Size   : " + metrics.getModeInsertSize());
    System.out.println();
  }
}
