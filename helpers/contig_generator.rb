#!/usr/bin/env ruby
#
# Generates a fasta file that is more managable for 
# the illumina squasher.
#
# Author::    David Rio Deiros  (mailto:deiros@bcm.edu)
# Copyright:: Copyright (c) 2008 David Rio Deiros
# License::   BSD License

fake_fname	 = "/users/dc12/Ttru20070419-assembly-scaffolds.fa"   # change this name for the path of the input file
final_fname    	 = "./final.fa"
n_splits 	 = 100
contig_separator = "N" * 50 + "\n" + "N" * 50 

# remove > + spaces and '\n' between contigs
puts "Finding number of lines of input file"
n_lines = `wc -l #{fake_fname}`.chomp.to_i

# Remove the original conting separators, add 
# N padding to separate them (so we avoid reads
# mapping to sequence that belongs to two contings.
# And finally add more padding in case we have 
# lanes that have < 50 bases
puts "Removing '>' ..."
`cat #{fake_fname} |
ruby -pe 'gsub(/^>.*$/, "#{contig_separator}")' |
ruby -ne 'foo=chomp; puts foo + ("N" * (50 - foo.chomp.size))' > ./out.txt`

#- split input in n splits... 
puts "Splitting input file ..."
`split -l #{n_lines/n_splits} out.txt`
`rm -f out.txt`

#- append > at the beginng.. 
puts "Appending '>' ..."
i = 1
Dir["x*"].each { |xfile|
  `echo ">fake#{i}" > #{xfile}.bak`
  `cat #{xfile} >> #{xfile}.bak`
  `rm -f #{xfile}`
  `mv #{xfile}.bak #{xfile}`
  i+=1
}

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
exit

#- cat them in one big file.. or not
puts "Merging all splits ..."
`rm -f #{final_fname}`
Dir["x*"].each { |xfile|
  `cat #{xfile} >> #{final_fname}`
  `rm -f #{xfile}`
}
