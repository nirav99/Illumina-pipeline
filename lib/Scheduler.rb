#!/usr/bin/ruby

# Class to encapsulate commands to scheduler (LSF for now)
class Scheduler
  def initialize(jobNamePrefix, jobCommand)
    @userCmd   = jobCommand
    @jobPrefix = jobNamePrefix
    @memory    = 4000              # Default to 4G memory
    @numCores  = 1                 # Default to 1 CPU core
    @stdoutLog = @jobPrefix + ".o" # Default to job name prefix + ".o"
    @stderrLog = @jobPrefix + ".e"
    @priority  = "normal"          # Default to normal queue
    @depList   = Array.new         # Dependency list
    @jobName   = ""
    @jobID     = ""
    buildJobName()
  end

  # Set the memory requirement for this job. Specify in giga bytes
  def setMemory(memoryReq)
    @memory = memoryReq.to_i
  end

  # Set the processor requirement for this job
  def setNodeCores(numCores)
    @numCores = numCores.to_i
  end

  # If priority is set to high, send to high queue
  # else schedule in normal queue
  def setPriority(priority)
    if priority.downcase.eql?("high")
     @priority = "high"
    end
  end

  # Get the name of the job to run
  def getJobName()
    return @jobName
  end

  # Get ID of the job running
  def getJobID()
    return @jobID
  end

  # Specify dependency either using job ID or job name
  def setDependency(preReq)
    @depList << preReq
  end

  # Method to run the scheduler command to run the job
  def runCommand()
    buildCommand()
    output = `#{@cmd}`
    exitStatus = $?
 
    if exitStatus == 0
      parseJobID(output)
    end

    puts output
    return exitStatus
  end
 
# private

 # Method to parse LSF job ID from output of bsub command
  def parseJobID(output)
    output.gsub!(/^Job\s+</, "")
    @jobID = output.slice(/\d+/)
  end

  # Method to build job name. Append process ID  and a random number to job name
  # prefix to generate a (usually) unique name
  def buildJobName()
    processID = $$
    @jobName = @jobPrefix + "_" + processID.to_s + "_" + rand(5000).to_s
  end

  # Method to build the LSF command
  def buildCommand()

    @cmd = "bsub -J " + @jobName + " -o " + @stdoutLog + " -e " + @stderrLog +
           " -q " + @priority + " -n " + @numCores.to_s

    dependency = buildDependencyList()

    if dependency != nil && !dependency.empty?
      @cmd = @cmd + dependency
    end

    @cmd = @cmd + " -R \"rusage[mem=" + @memory.to_s + "]span[hosts=1]\"" +
           " \"" + @userCmd + "\""
    puts @cmd.to_s 
  end

  # Method to create LSF command dependency
  def buildDependencyList()
    if @depList != nil && @depList.length > 0
      depCount = @depList.length
      depString = " -w '"

      for i in 0..(depCount - 1)
        depString = depString + "done(\"" + @depList.at(i) + "\")"

        if i < (depCount - 1)
          depString = depString + " && "
        end
      end
      depString = depString + "'"
      return depString
    else
      return ""
    end
  end

  @userCmd   = "" # User command to execute
  @jobPrefix = "" # Prefix of job name provided by the caller
  @memory    = 0  # memory in GB for the job
  @numCores  = 1  # Number of processor cores
  @stdoutLog = "" # File name for output from the job
  @stderrLog = "" # File name for stderr from the job
  @depList   = "" # Dependency list
  @priority  = "" # Priority of job (normal, high etc)
  @jobName   = "" # Complete name of the job
  @jobID     = "" # (LSF) ID of the job
  @cmd       = "" # Command for the scheduler
end
