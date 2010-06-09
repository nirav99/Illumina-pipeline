#!/usr/bin/env ruby
#
# $Id: summary_info.rb 495 2008-04-18 15:51:48Z dc12 $
#

#10-58-47_1192204727-CF071008_USI-EAS09_0002_FC8963-L6-Strep_pneumoniae/data_dir/
@date_num_sample = /\d\d-\d\d-\d\d_[0-9]+-CF[0-9]+_USI-[A-Za-z0-9]+_?[0-9]*_?[PE12]*_FC[0-9a-zA-Z]+-L[0-9]+-[\w_\-]*\/data_dir\// 

#09-26-07_10-13-02_1190819582-T_cuniculi_A/data_dir/
@date_date_sample = /[0-9\-]+_\d\d-\d\d-\d\d_[0-9]+_?[PE12]*-[0-9A-Za-z_\-]*\/data_dir\//  

#080114_USI-EAS09_R2_PE_FC13018AAXX-L5-phix/data_dir/
#080205_USI-EAS09_0002_PE1_FC13354AAXX-L2-staph_300/
@date_machine_FC = /[0-9]+_USI-[A-Za-z0-9]+_?[0-9]*_?[R2]*_?[PE12]*_FC[0-9a-zA-Z_]+-L[0-9]+-[\w_\-\.\+]*\/data_dir\// 

#FC8963-L3-PB07/data_dir
@fc_l_sample = /_?[PE12]*_?FC[A-Za-z0-9]+-L[0-9]+-[0-9A-Za-z_\-]+\/data_dir/


# Checks if the FC summary has been parsed before from the 
#  #{ENV['HOME']}/.completedFCSummary.txt file.
def check_fc(path, fcs_file)
  if File.file?(fcs_file)
    file = File.open(fcs_file,"r")
    while (line = file.gets)
      if Regexp.new(Regexp.escape(path)).match(line.chomp)
#        puts "This FC \"#{path}\" has been parsed before"
        return FALSE
#        exit
      end 
    end
    file.close
    
  end
#puts path
  return TRUE
end

# This method matches title with line_read and by passing 
#  back and forth of tag_count to grab the data while stripping 
#  off the <td></td> tags.  return tag_count, key_array, value_array 
def results_to_array(line_read, title, keys, values, tag_count)
  if /#{title}/.match(line_read)
     tag_count = 0
  end
  if tag_count < 3
    if /<\/tr>/.match(line_read)
      tag_count = tag_count + 1
    elsif /^<td>Lane <\/td>$/.match(line_read) && tag_count == 0
       tag_count = 1
       keys.push(line_read.gsub(/<td>\s*|\s*<\/td>/, ""))
    elsif tag_count == 1 && !/<tr>/.match(line_read)
       keys.push(line_read.gsub(/<td>\s*|\s*<\/td>/, ""))
    elsif tag_count == 2 && !/<tr>/.match(line_read)
       values.push(line_read.gsub(/<td>\s*|\s*<\/td>/, ""))
    end
  end
  return tag_count, keys, values
end

# this method will search for the fields with sd then split 
#  and push as two fields into the original index and the 
#  following index to keep the order of the array.  
# It will also update the key array and add another field for 
#  the std. The method will return the new key, value arrays
def split_sd (key_a, value_a)
  key_tmp_array = Array::new(0)
  value_tmp_array = Array::new(0)
  for i in 0...value_a.length
    if /\+\/\-/.match(value_a[i].to_s)
      tmp = value_a[i]
      tmp_pre = /^([\d.]+) \+\/\-/.match(tmp).to_s.gsub(/\s*\+\/\-/, "")
      tmp_post = /\+\/\- [\d.]+$/.match(tmp).to_s.gsub(/\+\/\-\s*/, "")
      value_tmp_array.push(tmp_pre, tmp_post)

      tmp = key_a[i].to_s.chomp
      key_tmp_array.push(tmp, "+/- SD #{tmp}")
    else
      value_tmp_array.push(value_a[i])
      key_tmp_array.push(key_a[i].to_s.chomp)
    end
  end
  return key_tmp_array, value_tmp_array
end

# search and extract the phasing and prephasing values from 
#  the passed in key, value arrays. returns new key_array 
#  and value_array
def extract_ph_preph( key_a, value_a )
  key_tmp_array = Array::new(0)
  value_tmp_array = Array::new(0)
  for i in 0...key_a.length
    if /Phasing/.match(key_a[i].to_s)
      key_tmp_array.push(key_a[i])
      value_tmp_array.push(value_a[i])
    elsif /Prephasing/.match(key_a[i].to_s)
      key_tmp_array.push(key_a[i])
      value_tmp_array.push(value_a[i])
    end
  end
  return key_tmp_array, value_tmp_array
end

# merges the key_array, and value_array together into a hash 
#  table where key_array[0] => value_array[0]. returns the hash
def merg_arrays_to_hash(key_a, value_a)
  tmp_hash = Hash::new()
  for i in 0...key_a.length
    tmp_hash =  tmp_hash.merge( {"#{key_a[i].to_s}" => "#{value_a[i].to_s}"} )
  end
  return tmp_hash
end

# parses through the file_path passed in and extract the run 
#  directory path, PE | PhageAlign, and name of the sample
def parse_file_path(path)
  parsed = parse_file_path_helper(path)
  tmp_array = Array::new(0)
  parsed.each { |x|
    if x ==""
      tmp_array.push("Fragment")
    else 
      tmp_array.push(x)
    end
  }
    return tmp_array.to_a
end

# helper method to parse all the fields from path
def parse_file_path_all_helper(path)
  if @date_machine_FC.match(path)
    return (/([0-9]+_USI-[A-Za-z0-9]+_?[0-9]*_?[R2]*_?[PE12]*_FC[0-9a-zA-Z]+)-L[0-9]+-[\w_\-\.\+]*/.match(path).to_a.reverse)
  end
end

# helper method to parse different fields
def parse_file_path_helper(path)
  if @date_num_sample.match(path)
    return  (/\d\d-\d\d-\d\d_[0-9]+-CF[0-9]+_USI-[A-Za-z0-9]+_?[0-9]*_?([PE12]*)_FC[0-9a-zA-Z]+-L[0-9]+-([\w_\-]*)/.match(path).to_a)
  elsif @date_date_sample.match(path)
   return (/[0-9\-]+_\d\d-\d\d-\d\d_[0-9]+_?([PE12]*)-([0-9A-Za-z_\-]*)/.match(path).to_a)
  elsif @date_machine_FC.match(path)
    return (/[0-9]+_USI-[A-Za-z0-9]+_?[0-9]*_?[R2]*_?([PE12]*)_FC[0-9a-zA-Z_]+-L[0-9]+-([\w_\-\.\+]*)/.match(path).to_a)
  elsif @fc_l_sample.match(path)
    return (/_?([PE12]*)_?FC[A-Za-z0-9]+-L[0-9]+-([0-9A-Za-z_\-]+)/.match(path).to_a)
  end
end

# combines output of parse_file_path with the fc_name. 
# Takes in the output from parse_file_path and fc_name. 
# Returns an array with fc_name, date, machine, type, fc, sample name
def fc_titles(fc_info, parsed_path_a)
  tmp_fc_array = /^([0-9]+)_(USI-[A-Za-z0-9]+)_?[0-9]*_?[R2]*_?[PE12]*_(F?C?[A-Za-z0-9]+)/.match(fc_info).to_a  
  tmp_fc_array << parsed_path_a.last
  tmp_fc_array[tmp_fc_array.length-2, 0] = parsed_path_a[1]
  return tmp_fc_array
end


# checks if file is valid if invalid then exit
def check(path)
  if (!File::exist?(path))
    puts "#{path} does not exists"
    return FALSE
  elsif ( /\/l|L[0-9]\//.match(path))
    return FALSE
  elsif(! /\/data_dir\//.match(path))
#    puts "not a /data_dir/"
    return FALSE
  else
    return TRUE
  end
end

# main method that calls methods parse through the file 
#  path and summary file.  returns two hash tables if 
#  its a PE FC, one full and one empty  hash if its a phagealign fc
def run_parse_summary(file_path, fcs_file)
  if check(file_path)
    sample = parse_file_path(file_path)
    if check_fc(sample[0].to_s, fcs_file)
      file = File.new(file_path, "r")
      lane_results_tag_count = 4
      expanded_lane_results_tag = 4
      key_array = Array::new(0)
      value_array = Array::new(0)
      key_sec_array = Array::new(0)
      value_sec_array = Array::new(0)

      if sample.member?("PE")  #initialize these only when its a PE
        key_b_array = Array::new(0)
        value_b_array = Array::new(0)
        key_sec_b_array = Array::new(0)
        value_sec_b_array = Array::new(0)
        lane_b_results_tag_count = 4
        expanded_lane_b_results_tag = 4
      end

      while (line = file.gets)
        break if /IVC Plots/.match(line)
        if  /[0-9]+_USI-[A-Za-z0-9]+_?[0-9]*_?[A-Za-z0-9]*_?[PE12]*_(FC)?[0-9a-zA-Z_]+ Summary/.match(line)
          fc_name =  /([0-9]+_USI-[A-Za-z0-9]+_*[0-9]*_*[A-Za-z0-9]*_?[PE12]*_(FC)?[0-9a-zA-Z_]+)/.match(line)
        end

        if ( lane_results_tag_count != 3 ) # grabs the lane results summary fields
          lane_results_tag_count, key_array, value_array  = results_to_array( line, "Lane Results Summary", key_array, value_array, lane_results_tag_count)
        elsif ( lane_results_tag_count == 3 && expanded_lane_results_tag !=3) # grabs the expanded lane summary fields
          expanded_lane_results_tag, key_sec_array, value_sec_array  = results_to_array( line, "Expanded Lane Summary", key_sec_array, value_sec_array, expanded_lane_results_tag)
        end
        if sample.member?("PE")
          if ( lane_b_results_tag_count != 3 ) # grabs the lane results summary fields
            lane_b_results_tag_count, key_b_array, value_b_array  = results_to_array( line, "Lane Results Summary : Read 2", key_b_array, value_b_array, lane_b_results_tag_count)
          elsif ( lane_b_results_tag_count == 3 && expanded_lane_b_results_tag !=3)
            expanded_lane_b_results_tag, key_sec_b_array, value_sec_b_array  = results_to_array( line, "Expanded Lane Summary : Read 2", key_sec_b_array, value_sec_b_array, expanded_lane_b_results_tag)
          end
        end
      end
      if fc_name.to_s == ""
        fc_name = parse_file_path_all_helper(file_path)
      end
      fc_values = fc_titles(fc_name.to_s, sample.to_a)
      key_sec_array, value_sec_array = extract_ph_preph(key_sec_array, value_sec_array)
      key_array.concat(key_sec_array)
      value_array.concat(value_sec_array)
      key_array, value_array = split_sd(key_array, value_array)
      fc_keys = [:fc_name, :date_created, :instrument, :type, :fc, :sample]
      fc_hash = merg_arrays_to_hash(fc_keys, fc_values)
      output_hash = merg_arrays_to_hash(key_array, value_array)
      output_hash.update(fc_hash)
      output_b_hash = {}
      if sample.member?("PE")
        key_sec_b_array, value_sec_b_array = extract_ph_preph(key_sec_b_array, value_sec_b_array)
        key_b_array.concat(key_sec_b_array)
        value_b_array.concat(value_sec_b_array)
        key_b_array, value_b_array = split_sd(key_b_array, value_b_array)
        output_b_hash = merg_arrays_to_hash(key_b_array, value_b_array)
      end
      return sample.to_a.reverse.pop.to_s, output_hash, output_b_hash
    end
  end
  return "",[], []
end
