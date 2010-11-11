#!/bin/bash

picardPath="/stornext/snfs5/next-gen/software/picard-tools/current"
samJarName=`ls $picardPath"/"sam-*.jar`
picardJarName=`ls $picardPath"/"picard-*.jar`
outJarName="BAMAnalyzer.jar"

rm -rf $outJarName *.class

echo "SAM Jar : "$samJarName
echo "Picard Jar : "$picardJarName

echo "Compiling project"
javac -classpath $samJarName *.java


echo "Generating Manifest file"
manifestFile=`pwd`"/BAMAnalyzerManifest.txt"

echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: Driver\n" > $manifestFile

echo "Building Jar file"

jar cvfm $outJarName $manifestFile *.class
