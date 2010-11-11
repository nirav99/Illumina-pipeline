#!/bin/bash
jarFileName=SlxUniqueness.jar
manifestFile=SlxUniqueness_Manifest.txt

rm *.class
rm $jarFileName
echo "Compiling Java Classes"
javac *.java
echo "Generating Manifest File"
echo -e "Main-Class: Driver\n" > $manifestFile 
echo "Generating Jar"
jar cvfm $jarFileName $manifestFile *.class
