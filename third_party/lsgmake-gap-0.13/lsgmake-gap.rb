#! /usr/bin/env ruby
#= NAME
#lsgmake-gap - runs the Illumina GAPipeline in parallel on an LSF cluster.
#
#= SYNOPSIS
#lsgmake-gap [OPTIONS]... [TARGET]
#
#= DESCRIPTION
#The parallelization is based on the
#{Genome Analyzer Pipeline documentation}[https://gscweb.gsc.wustl.edu/gscdoc/solexa/pipeline/Pipeline%20parallelisation.html]
#and uses LSF to run jobs and manage dependencies between jobs.  This
#script should be run after you have run goat_pipeline.py, creating the
#Data directory and necessary Firecrest and Bustard Makefiles.  If you
#have also already run GERALD.pl (either using the --GERALD option to
#goat_pipeline.py or directly), you must be sure to include the following
#line in your GERALD configuration file if you are using the ELAND
#aligner.
#
#  ELAND_MULTIPLE_INSTANCES 8
#
#If this script is run with no arguments, it will try to figure out
#what kind of directory it is in and make all the targets for that
#directory.
#
#If you have specified automatic calibration in the GERALD
#configuration file, this script will pick that up and alter the
#jobs submitted and their dependencies accordingly.  Note that you will
#need to use provide the --with-qval option to goat_pipeline.py for
#auto-calibration to work.
#
#The targets and dependencies in Bustard changed in GAPipeline1.3.  This
#automatically detects that and adjusts the targets/dependencies
#accordingly.
#
#Each target is submitted as a separate job to LSF and generates a separate
#stdout/stderr file with a name like <tt>make-TARGET-JOBID.out</tt>.
#
#= OPTIONS
#If an argument to a long option is mandatory, it is also mandatory for
#the corresponding short option; the same is true for optional arguments.
#
#<tt>--bsub-options</tt> _BSUBOPTIONS_::
#    Pass along _BSUBOPTIONS_ to all bsub commands.
#
#<tt>--dependency</tt> _LSFJOBID_::
#    Make the first set of jobs submitted have a dependency on
#    _LSFJOBID_ (see --status to set type of dependency).
#
#<tt>--help</tt>::
#    Output this information.
#
#<tt>--id</tt> _ID_::
#    Specify unique identifier, _ID_, to incorporate into job name.
#
#<tt>--jobs</tt> N::
#    Run N jobs on a single node.  N should be equal to the number of slots
#    on each node.  The default N is 1.  Each target is sent to a single node
#    using the <tt>span[hosts=1]</tt> resource specification to the bsub
#    command.
#
#<tt>--lanes</tt> K,L,M,N::
#    If there are bad lanes in a run and you do not want them
#    analyzed, you can have the script only submit jobs for specific
#    lane targets rather than all the lanes, 1 through 8.  Use
#    this command-line option and only list the lanes you want
#    analyzed.  Note that you will still have to run goat_pipeline.py
#    and have a GERALD configuration file that selects specific lanes
#    for analysis.
#
#<tt>--path</tt> _PATH_::
#    Run make in directory _PATH_ rather than current directory.
#
#<tt>--queue</tt> _QUEUE_::
#    Submit all jobs to LSF queue _QUEUE_ rather than the default.
#
#<tt>--resource</tt> _RESOURCE_::
#    In addition to the <tt>span[hosts=1]</tt> resource specification
#    added to each bsub command, also specify the resource RESOURCE.
#
#<tt>--status</tt> _STATUS_::
#    Use job status dependency of STATUS rather than done (finish normally
#    with a zero exit value).
#
#<tt>--test</tt>::
#    Just print out what commands would be run, do not actually submit
#    any jobs.
#
#<tt>--version</tt>::
#    Output command name and version.
#
#= EXAMPLES
#To run Firecrest, Bustard, and GERALD for the run in
#
#  /gscmnt/sata100/techd/RUN_NAME/Data/CN-M_FirecrestVERSION-DATE
#
#You can either do this
#
#  $ cd /gscmnt/sata100/techd/RUN_NAME/Data/CN-M_FirecrestVERSION-DATE
#  $ lsgmake-gap recursive
#
#or this
#
#  $ lsgmake-gap --path=/gscmnt/sata100/techd/RUN_NAME/Data/CN-M_FirecrestVERSION-DATE recursive
#
#If no GERALD directory exists, it will exit gracefully after
#completing Bustard.  You can still run GERALD separately as you always
#have.
#
#  $ cd .../GERALD
#  $ lsgmake-gap
#
#or
#
#  $ lsgmake-gap --path=.../GERALD
#
#If a specific part of the pipeline fails, e.g., the s_7 target in the
#Bustard directory, you should kill the pending LSF jobs, change to the
#Bustard directory, and run
#
#  $ lsgmake-gap recursive
#
#While all the jobs names will be the same, LSF is not smart enough to
#figure that out and pick up that the original job failed and another
#with the same name was subsequently submitted and completed successfully.
#
#To only analyze lanes 3 and 4, create a GERALD configuration file,
#named, for example, +gerald34.config+ that has a line like this
#
#  125678:ANALYSIS none
#
#and then run goat_pipeline.py like this
#
#  $ goat_pipeline.py --make --tiles=s_3,s_4 --GERALD=gerald34.config .
#
#Finally, run this script in the Firecrest directory like this
#
#  $ lsgmake-gap --lanes 3,4 recursive
#
#If you want to schedule jobs before the run is completed, you can
#use the <tt>-b</tt> option to bsub when running your goat_pipeline.py command
#(since you will not want to run goat_pipeline.py until the run completes).
#If you determine the run will complete on 15 June at 2:30 p.m.,
#then you can run the following command to submit the goat_pipeline.py job
#
#  $ bsub -q short -b 6:15:14:30 -J DIR.goat -o goat.out goat_pipeline.py --make --GERALD=gerald.config Run/DIR
#
#then use the <tt>-w</tt> option to bsub so lsgmake-gap will not
#run until the goat jobs completes (the Firecrest directory must exist when
#lsgmake-gap runs)
#
#  $ bsub -q short -w DIR.goat -o lsgmake-gap.out lsgmake-gap --path Run/DIR
#
#If you run GERALD.pl after you have already run lsgmake-gap on the
#Firecrest and Bustard directories, you can submit the GERALD jobs before
#the Bustard jobs complete using the <tt>--dependency</tt> option.  If the
#job name of the last Bustard job is
#s070613_SLXA-EAS8_0000_5751.Bustard1.8.28_15-06-2007_mhickenb.all,
#you would run
#
#  $ lsgmake-gap --dependency s070613_SLXA-EAS8_0000_5751.Bustard1.8.28_15-06-2007_mhickenb.all --path Firecrest/Bustard/GERALD
#
#= SEE ALSO
#bsub(1), https://gscweb.gsc.wustl.edu/gscdoc/solexa/pipeline/
#
#= AUTHOR
#David Dooling <mailto:ddooling@wustl.edu>
#
#= COPYRIGHT
#Copyright (C) 2009 Washington University in St. Louis
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#--
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++

$VERBOSE = true
$pkg = 'lsgmake-gap'
require 'optparse'
require 'rdoc/usage'

# extend Dir class
# glob for only a single item
def Dir.uglob(pattern, must_find = false)
  paths = Dir.glob(pattern)
  if must_find && paths.length < 1
    raise RuntimeError,
      "no path matching #{pattern} found",
      caller
  end
  if paths.length > 1
    raise RuntimeError,
      "more than one path matching #{pattern} found: #{paths.join(' ')}",
      caller
  end
  paths.last
end

#submit a make job to lsf
#= Usage
# 
#   bmake = BsubMake.new('name', 'target')
#   bmake.dependency(*array_of_previous_jobs)
#   bmake.submit
# 
class BsubMake
  attr_reader :job_name, :target
  attr_accessor :jobs
  @@bsub_options = ''
  @@id = ''
  @@jobs = 1
  @@queue = ''
  @@resource = ''
  @@status = 'done'
  @@test = false

  def initialize(job_name, target)
    # set job name, removing illegal characters
    @job_name = 's' + @@id + job_name.gsub(%r{[^\-.\w]+}, '-')
    @target = target
    @submitted = false
    @dependency = ''
    @job_name_array = ''
    @jobs = @@jobs
  end

  # supply arbitrary command-line options to bsub
  def self.bsub_options
    @@bsub_options
  end
  def self.bsub_options=(bsub_options)
    @@bsub_options = bsub_options
  end

  # unique id to put in job name
  def self.id
    @@id
  end
  def self.id=(id)
    @@id = id
  end

  # number of jobs to run in parallel
  def self.jobs
    @@jobs
  end
  def self.jobs=(jobs)
    @@jobs = jobs
  end

  # queue to submit jobs to
  def self.queue
    @@queue
  end
  def self.queue=(queue)
    @@queue = queue
  end

  # extra resource specifications for bsub command
  def self.resource
    @@resource
  end
  def self.resource=(resource)
    @@resource = resource
  end

  # extra resource specifications for bsub command
  def self.status
    @@status
  end
  def self.status=(status)
    @@status = status
  end

  # if true, print what would be run (do not submit jobs)
  def self.test
    @@test
  end
  def self.test=(test)
    @@test = test
  end

  # submit a job array
  def job_array(indices)
    @job_name_array = '[' + indices.join(',') + ']'
  end

  # define dependencies for other jobs
  def dependency(*dependencies)
    # bsub -w 'done("JOBNAME")'
    deps = dependencies.map { |d| %Q{#{@@status}(#{d})} }
    @dependency = deps.join(' && ')
  end

  # submit the jobs to the default LSF queue
  def submit
    # do not submit twice
    return false if @submitted

    # initialize resource request
    resource = @@resource

    # create bsub command
    bsub = Array.new(['bsub'])
    if @jobs > 1
      bsub.push('-n', @jobs.to_s)
      resource += ' span[hosts=1]'
    end
    bsub.push('-q', @@queue) if @@queue.length > 0
    bsub.push('-R', resource) if resource.length > 0
    bsub.push('-o', "make-#{@target}-%J.out".gsub(%r{/+}, '-'))
    bsub.push('-J', @job_name + @job_name_array)
    bsub.push('-w', @dependency) if @dependency.length > 0
    bsub.push(@@bsub_options) if @@bsub_options.length > 0

    # append the actual make command
    bsub.push('make')
    bsub.push('-j', @jobs.to_s) if @jobs > 1
    bsub.push(@target.gsub(/%I/, '${LSB_JOBINDEX}'))

    # just echo if testing
    bsub.unshift('echo') if @@test

    # run the command
    if !system(*bsub)
      return false
    end
    rv = $?.exitstatus
    @submitted = true
    # wait a bit
    sleep 1 unless @@test
    rv
  end
end

#submit jobs, one per lane
#
#= Usage
# 
#   MakeLanes.lanes(4..8)
#   job_name_base = 'myrun'
#   slx = MakeLanes.new(job_name_base, 's_%I')
#   slx.submit or puts "failed to submit #{job_name_base}"
#   job = slx.job_name
# 
class MakeLanes
  attr_reader :job_name
  # analyze all lanes by default
  @@lanes = ('1'..'8').collect { |x| x.to_s }

  def initialize(run_name, target_pattern)
    @run_name = run_name
    @target_pattern = target_pattern
    @dependency = false
  end

  # lanes to analyze
  def self.lanes
    @@lanes
  end
  def self.lanes=(lanes)
    # make sure they are strings
    @@lanes = lanes.collect { |x| x.to_s }
  end

  # set a single dependency for all jobs
  def dependency(dep)
    @dependency = dep
  end
  
  # submit job array for lanes
  def submit
    @job_name = @run_name + '.' + @target_pattern.gsub(/%I/, 'N')
    bmake = BsubMake.new(@job_name, @target_pattern)
    bmake.job_array(@@lanes)
    bmake.dependency(@dependency) if @dependency
    if !bmake.submit
      return false
    end
    @job_name = bmake.job_name
  end
end

#base class for all Solexa make classes
#
#= Usage
# 
#   make = SolexaMake.new(
#                         :path       => '/path/to/RUN/Data/DIRECTORY',
#                         :run        => 'RUN',
#                         :dependency => job_name,
#                         :target     => 'all'
#                        )
#   make.submit or puts "failed to submit jobs"
#
class SolexaMake
  def initialize(options)
    # save options
    @options = options
    # check path
    if @options[:path]
      @path = @options[:path]
    else
      raise ArgumentError, "no path provided", caller
    end
    if !File.directory?(@path)
      raise ArgumentError, "path is not a directory: #{@path}", caller
    end

    # check run name
    if @options[:run]
      @run = @options[:run]
    else
      raise ArgumentError, "no run name provided", caller
    end

    # set target
    if @options[:target]
      @target = @options[:target]
    else
      @target = 'all'
    end

    # check for bsub dependency
    if @options[:dependency]
      @dependency = @options[:dependency]
    else
      @dependency = false
    end

    # set basename for job
    @job_name_base = @run + '.' + File.basename(@path)
  end

  # the master method that submits all necessary make jobs to LSF
  def submit
    # must run makes in proper directory
    Dir.chdir(@path) do
      case @target
      when 'all', 'recursive'
        make_all
      else
        make_target
      end
    end
  end

  # make a specific target
  def make_target
    puts "#{self.class}: submitting #{@target} job"
    bmake = BsubMake.new("#{@job_name_base}.#{@target}", @target)
    bmake.dependency(@dependency) if @dependency
    bmake.submit
  end

  # make s_N targets and all
  def make_all
    # s_N jobs
    puts "#{self.class}: submitting s_N job"
    lanes = MakeLanes.new(@job_name_base, 's_%I')
    lanes.dependency(@dependency) if @dependency
    return false if !lanes.submit

    # final make
    puts "#{self.class}: submitting all job"
    all = BsubMake.new("#{@job_name_base}.all", 'all')
    @all_job_name = all.job_name
    all.dependency(lanes.job_name)
    # avoid make parallelization bug
    all.jobs = 1
    all.submit
  end

  # run make in subdirectory
  def make_subdir(cls, dep = false)
    # get sub directory
    glob = "#{@path}/#{cls.glob}*"
    sub = Dir.uglob(glob)
    if !sub
      puts "#{self.class}: no subdirectory matching #{glob} found"
      return true
    end

    # create sub make object
    sub_options = @options
    sub_options[:path] = sub
    sub_options[:dependency] = dep if dep
    smake = cls.new(sub_options)
    smake.submit
  end
end

#director class to initiate all Firecrest jobs
class FirecrestMake < SolexaMake
  # glob pattern for Firecrest directories
  def self.glob
    'C[1-9]'
  end

  # make default_offsets.txt before the s_N and all targets
  def make_all
    # offsets
    puts "#{self.class}: submitting offsets job"
    offsets = BsubMake.new("#{@job_name_base}.default_offsets",
                           'default_offsets.txt')
    offsets.dependency(@dependency) if @dependency
    return false if !offsets.submit

    # make s_N (image analysis) and all targets
    @dependency = offsets.job_name
    super or return false

    # see if we should run Bustard
    return true if @options[:target] != 'recursive'
    make_subdir(BustardMake, @all_job_name)
  end
end

#director class to initiate all Bustard jobs
class BustardMake < SolexaMake
  def initialize(options)
    # call parent
    super(options)

    check_version
  end
  # glob pattern for Bustard directories
  def self.glob
    'Bustard[0-9]'
  end

  # check version to set dependency chain
  def check_version
    @matrix = false
    if (%r{^Bustard1.3}.match(File.basename(@path)))
      @matrix = true
    end
  end

  # make matrix and phasing targets
  def make_matrix_phasing
    # see if matrix and new-style phasing targets are needed
    if @matrix
      # lane matrix
      puts "#{self.class}: submitting lane matrix job"
      lane_matrix = MakeLanes.new(@job_name_base, 'matrix_%I_finished.txt')
      lane_matrix.dependency(@dependency) if @dependency
      lane_matrix.submit or return false

      # matrix
      puts "#{self.class}: submitting matrix job"
      matrix = BsubMake.new("#{@job_name_base}.matrix", 'matrix')
      matrix.dependency(lane_matrix.job_name)
      matrix.submit or return false

      # lane phasing
      puts "#{self.class}: submitting lane phasing job"
      lane_phasing = MakeLanes.new(@job_name_base, 'phasing_%I_finished.txt')
      lane_phasing.dependency(matrix.job_name)
      lane_phasing.submit or return false

      # phasing
      puts "#{self.class}: submitting phasing job"
      phasing = BsubMake.new("#{@job_name_base}.phasing", 'phasing_finished.txt')
      phasing.dependency(lane_phasing.job_name)
      phasing.submit or return false
    else # old-style phasing targets
      # lane phasing
      puts "#{self.class}: submitting lane phasing job"
      lane_phasing = MakeLanes.new(@job_name_base, 'Phasing/s_%I_phasing.xml')
      lane_phasing.dependency(@dependency) if @dependency
      lane_phasing.submit or return false

      # phasing
      puts "#{self.class}: submitting phasing job"
      phasing = BsubMake.new("#{@job_name_base}.phasing", 'Phasing/phasing.xml')
      phasing.dependency(lane_phasing.job_name)
      phasing.submit or return false
    end

    # set dependecy for s_N jobs
    @dependency = phasing.job_name

    true
  end

  # make phasing targets before s_N and all targets
  def make_all
    # make the correct pre-requisites
    make_matrix_phasing or return false

    # make s_N (base calling) and all targets
    super or return false

    # see if we should run GERALD
    return true if @options[:target] != 'recursive'
    make_subdir(GeraldMake, @all_job_name)
  end
end

#director class to initiate all GERALD jobs
class GeraldMake < SolexaMake
  def initialize(options)
    # call parent
    super(options)

    # check for auto-calibration
    check_acal
  end

  # glob pattern for GERALD directories
  def self.glob
    'GERALD_[0-9]'
  end

  # determing if auto-calibration targets are needed
  def check_acal
    @autocal = 0
    # check for GERALD config
    config = @path + '/config.txt'
    if File.exist?(config) && File.readable?(config)
      # open config
      File.open(config) do |conf|
        while line = conf.gets
          case line
          when %r{QCAL_SOURCE.*auto\d}
            # determine what lane is being used for auto calibration
            autore = Regexp.new(%r{auto(\d)})
            autom = autore.match(line)
            @autocal = Integer(autom[1]) if autom
          end
        end
      end
    end
  end

  # make tiles.txt before s_N and all targets
  def make_all
    # tiles.txt
    puts "#{self.class}: submitting tiles job"
    tiles = BsubMake.new("#{@job_name_base}.tiles", 'tiles.txt')
    tiles.dependency(@dependency) if @dependency
    tiles.submit or return false
    # set dependecy for super jobs
    @dependency = tiles.job_name

    # autocalibration target
    if @autocal > 0
      puts "#{self.class}: submitting qtable job"
      target = "s_#{@autocal}_QTABLES"
      qtable = BsubMake.new("#{@job_name_base}.#{target}", target)
      qtable.dependency(tiles.job_name)
      qtable.submit or return false

      # reset dependency for super jobs
      @dependency = qtable.job_name
    end

    # make s_N (alignment) and all targets
    super
 end
end

## main
# process command line options
options = {}
OptionParser.new do |opts|
  opts.release = $pkg
  opts.version = '0.13'
  opts.banner = "Usage: #{$pkg} [OPTIONS] [TARGET]"

  opts.on('-b', '--bsub-options BSUBOPTIONS', 'Add options to bsub commands') do |bsub_options|
    BsubMake.bsub_options = bsub_options
  end
  opts.on('-d', '--dependency JOBID', 'Set dependency for initial job on JOBID') do |jobid|
    options[:dependency] = jobid
  end
  opts.on('-i', '--id ID', 'Add identifier to job name') do |id|
    BsubMake.id = id
  end
  opts.on('-j', '--jobs N', Integer, 'Allow N jobs at once (default 1)') do |jobs|
    if jobs < 1
      raise ArgumentError, "number of jobs must be greater than zero", caller
    end
    BsubMake.jobs = jobs
  end
  opts.on('-l', '--lanes K,L,N,M', Array,
          'Only make the provided lane targets') do |lanes|
    MakeLanes.lanes = lanes
  end
  opts.on('-p', '--path PATH', 'Run make in directory PATH') do |path|
    options[:path] = path
  end
  opts.on('-q', '--queue QUEUE', 'Submit jobs to LSF queue QUEUE') do |queue|
    BsubMake.queue = queue
  end
  opts.on('-R', '--resource RESOURCE', 'Resource specification for bsub') do |resource|
    BsubMake.resource = resource
  end
  opts.on('-s', '--status STATUS', 'Use job dependency STATUS rather than done') do |status|
    BsubMake.status = status
  end
  opts.on('-t', '--test', 'Just echo commands, do not submit') do |x|
    BsubMake.test = true
  end
end.parse! rescue RDoc::usage(1, 'synopsis', 'options')

# see if path was given
if options[:path]
  # get absolute path
  options[:path] = File.expand_path(options[:path])
else
  options[:path] = Dir.getwd
end
# see if target was given
if ARGV.length > 0 && ARGV[0].length > 0
  options[:target] = ARGV[0]
end

# see what kind of directory we have
path = options[:path].sub(%r{/+$}, '')
dirs = path.split(%r{/+})
make = case dirs.last
       when %r{^#{FirecrestMake.glob}}
         options[:run] = dirs[-3]
         FirecrestMake.new(options)
       when %r{^#{BustardMake.glob}}
         options[:run] = dirs[-4]
         BustardMake.new(options)
       when %r{^#{GeraldMake.glob}}
         options[:run] = dirs[-5]
         GeraldMake.new(options)
       when 'Data'
         # find a firecrest directory
         firecrest = Dir.uglob("#{path}/#{FirecrestMake.glob}*", true)
         options[:path] = firecrest
         options[:run] = dirs[-2]
         FirecrestMake.new(options)
       else
         # see if this is the run directory
         if File.directory?("#{path}/Data") && File.directory?("#{path}/Images")
           firecrest = Dir.uglob("#{path}/Data/#{FirecrestMake.glob}*", true)
           options[:path] = firecrest
           options[:run] = dirs.last
           FirecrestMake.new(options)
         else
           puts "#{$pkg}: unrecognized directory: #{dirs.last}"
           exit(1)
         end
       end

# submit make jobs to lsf
if !make.submit
  puts "#{$pkg}: submission of jobs failed"
  exit(2)
end

exit(0)
