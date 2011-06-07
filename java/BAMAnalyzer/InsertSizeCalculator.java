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
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import net.sf.picard.sam.SamPairUtil.PairOrientation;
import net.sf.samtools.*;
import net.sf.picard.sam.*;

/**
 * @author Nirav Shah niravs@bcm.edu Class to calculate insert size. Insert size
 *         values are shown only for the orientation that is at least 10% of the
 *         total number of pairs.
 */
public class InsertSizeCalculator implements MetricsCalculator
{
  /* Metrics for read pairs having f->r orientation*/
  private InsertSizeMetrics frMetrics; 

  /* Metrics for read pairs having r->f orientation*/
  private InsertSizeMetrics rfMetrics; 
	
  /* Metrics for read pairs having tandem orientation*/
  private InsertSizeMetrics tandemMetrics; 
  
  private int totalPairs            = 0; // Total read pairs
  private double percentReadPairs   = 0; 
  private int totalMappedPairs      = 0; // Pairs where both reads are mapped
  private double percentMappedPairs = 0;

  /**
   * Class constructor
   */
  public InsertSizeCalculator()
  {
    frMetrics = new InsertSizeMetrics(PairOrientation.FR);
    rfMetrics = new InsertSizeMetrics(PairOrientation.RF);
    tandemMetrics = new InsertSizeMetrics(PairOrientation.TANDEM);
  }

  /**
   * Public method to process a record for insert size calculations
   * 
   * @param record - SAMRecord
   */
  @Override
  public void processRead(SAMRecord record)
  {
    // On encountering a paired read for the second read, increment
    // total number of pairs
    if (record.getReadPairedFlag() && !record.getFirstOfPairFlag())
    {
      totalPairs++;
    }
    if (!record.getReadPairedFlag() || record.getReadUnmappedFlag()
        || record.getMateUnmappedFlag()
        || record.getFirstOfPairFlag()
        || record.getNotPrimaryAlignmentFlag()
        || record.getDuplicateReadFlag()
        ||
        // record.getInferredInsertSize() == 0 ||
        !record.getMateReferenceName().equals(record.getReferenceName()))
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
  @Override
  public void showResult()
  {
    if (totalMappedPairs <= 0)
      return;

    if(totalPairs > 0)
      percentMappedPairs = 1.0 * totalMappedPairs / totalPairs * 100.0;
    
    if(frMetrics.getTotalPairs() > totalMappedPairs * 0.1)
      frMetrics.showResult(totalMappedPairs);

    if(rfMetrics.getTotalPairs() > totalMappedPairs * 0.1)
      rfMetrics.showResult(totalMappedPairs);

    if(tandemMetrics.getTotalPairs() > totalMappedPairs * 0.1)
      tandemMetrics.showResult(totalMappedPairs);
    
    System.out.println(toString());
    /*
      System.out.println("Insert Size Calculations");
      System.out.println();
      System.out.println("Pairs with Both Reads Mapped on same Chr  : "
				+ totalMappedPairs);
      System.out.format("%% Pairs with Both Reads Mapped on same Chr : %.2f%%\n", 1.0
						* totalMappedPairs / totalPairs * 100.0);
      System.out.println();

     if(frMetrics.getTotalPairs() > totalMappedPairs * 0.1)
     {
       frMetrics.showResult(totalMappedPairs);
     }

     if(rfMetrics.getTotalPairs() > totalMappedPairs * 0.1)
     {
       rfMetrics.showResult(totalMappedPairs);
     }

     if(tandemMetrics.getTotalPairs() > totalMappedPairs * 0.1)
     {
       tandemMetrics.showResult(totalMappedPairs);
     }
     */
  }

  @Override
  public String toString()
  {
    String newLine = "\r\n";
    StringBuilder resultString = new StringBuilder("Insert Size Calculations" + newLine);
    resultString.append(newLine);
    resultString.append("Pairs with Both Reads Mapped on same Chr  : "+ totalMappedPairs);
    resultString.append(newLine);
    resultString.append("% Pairs with Both Reads Mapped on same Chr : ");
    resultString.append(String.format("%.2f", percentMappedPairs) + "%");
    resultString.append(newLine);
    resultString.append(newLine);
    
    if(frMetrics.getTotalPairs() > totalMappedPairs * 0.1)
    {
      resultString.append(frMetrics.toString());
      resultString.append(newLine);
    }
    
    if(rfMetrics.getTotalPairs() > totalMappedPairs * 0.1)
    {
      resultString.append(rfMetrics.toString());
      resultString.append(newLine);
    }
    
    if(tandemMetrics.getTotalPairs() > totalMappedPairs * 0.1)
    {
      resultString.append(tandemMetrics.toString());
      resultString.append(newLine);
    }

    return resultString.toString();
  }

  @Override
  public Element toXML(Document doc)
  {
    Element rootElem = doc.createElement("InsertSizeMetrics");

    if(frMetrics.getTotalPairs() > totalMappedPairs * 0.1)
    {
      rootElem.appendChild(frMetrics.toXML(doc));
    }

    if(rfMetrics.getTotalPairs() > totalMappedPairs * 0.1)
    {
      rootElem.appendChild(rfMetrics.toXML(doc));
    }

    if(tandemMetrics.getTotalPairs() > totalMappedPairs * 0.1)
    {
      rootElem.appendChild(tandemMetrics.toXML(doc));
    }
    return rootElem;
  }
}
