#!/bin/bash

outJarName="AttachmentMailer.jar"

rm -rf $outJarName *.class

echo "Compiling project"
javac -classpath ./mail.jar *.java

echo "Generating Manifest file"
manifestFile=`pwd`"/AttachmentMailer.txt"

echo -e "Class-Path: ./mail.jar \nMain-Class: Driver\n" > $manifestFile

echo "Building Jar file"

jar cvfm $outJarName $manifestFile *.class
chmod +x $outJarName
cp $outJarName ../
cp mail.jar ../
