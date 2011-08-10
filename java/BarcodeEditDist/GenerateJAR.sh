#!/bin/bash

outJarName="BarcodeEditDistCalculator.jar"

rm -rf $outJarName *.class

echo "Compiling project"
javac *.java

echo "Generating Manifest file"
manifestFile=`pwd`"/BarcodeEditDistCalcManifest.txt"

echo -e "Main-Class: BarcodeEditDist\n" > $manifestFile

echo "Building Jar file"
jar cvfm $outJarName $manifestFile *.class
