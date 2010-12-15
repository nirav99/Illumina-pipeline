#!/bin/bash

# This script can be used to send Summary.htm (at the end of GERALD phase) after
# early detection analysis finishes.
# It uses SlxResultSummaryMailer.jar to send email, which in turn depends on
# Mail.jar. Both these should be in the same directory as this script.
# This script should be executed from the directory of GERALD analysis, where
# the Summary.htm file is present.

attachFile="Summary.htm"

# pwd -P commands prints the actual path, not the linked path
bodyText="The path to the Summary.htm file is : "`pwd -P`
#emailDest="niravs@bcm.edu"
emailDest="jgreid@bcm.edu niravs@bcm.edu yhan@bcm.edu fongeri@bcm.edu javaid@bcm.edu dc12@bcm.edu english@bcm.edu"
emailSub="Slx Analysis Result Summary"

java -jar /stornext/snfs5/next-gen/Illumina/ipipe/java/SlxResultSummaryMailer.jar \
slx_pipeline@bcm.edu "$emailSub" $attachFile "$bodyText" $emailDest
