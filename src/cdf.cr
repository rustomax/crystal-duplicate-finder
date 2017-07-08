require "./optparse"
require "colorize"
require "murmur3"

module Dedup
  # Returns file list matching specific pattern from filesystem
  def Dedup.get_from_fs(options)
    print "\nStep 1/5: Getting the list of files               "
    file_list = Array(String).new
    path = options.root_dir + options.pattern
    begin
      file_list = Dir[path]
    rescue
      print_error_message "Fatal: Could not read '#{options.root_dir}'", true
    else
      puts "#{file_list.size} total files and directores".colorize :green
    end
    file_list
  end

  # Narrows down the list of possible duplicate candidates
  # by filtering out files based on file type and user-selected options
  # i.e hidden or zero-length files, directories, etc.
  def Dedup.filter_by_file_type(file_list, options)
    print "Step 2/5: Narrowing down the list (by options)    "
    filtered_file_list = Array(String).new
    file_list.each do |file|
      begin
        file_stats = File.stat(file)
        if file_stats.file? && !file_stats.symlink? &&
           (file_stats.size != 0 || options.zero_len) &&
           (File.basename(file)[0] != '.' || options.hidden)
          filtered_file_list << file
        end
      rescue
        # silently ignore files we could not get sizes for
      end
    end
    puts "#{filtered_file_list.size} candidates found".colorize :green
    filtered_file_list
  end

  # Narrows down the list of possible duplicate candidates
  # by filtering out files with unque sizes
  def Dedup.filter_by_size(file_list)
    print "Step 3/5: Narrowing down the list (by size)       "
    filtered_file_list = Array(String).new
    sizes = {} of UInt64 => Array(String)
    file_list.each do |file|
      begin
        size = File.size file
      rescue
        # silently ignore files we could not get sizes for
      else
        if sizes[size]?
          sizes[size] += [file]
        else
          sizes[size] = [file]
        end
      end
    end
    sizes.each do |size, files|
      if files.size > 1
        files.each do |file|
          filtered_file_list << file
        end
      end
    end
    puts "#{filtered_file_list.size} candidates found".colorize :green
    filtered_file_list
  end

  # Hash all files in the file_list and return a Hash with duplicates only
  def Dedup.find_dups_by_hash(file_list)
    print "Step 4/5: Identifying duplicates (may take a bit) "
    all_hashes = {} of String => Array(String)
    duplicate_hashes = {} of String => Array(String)
    file_list.each do |file|
      begin
        # TODO: Find more efficient way to do this for large files
        buffer = File.new file
        hash = "F" + Murmur3.h1(buffer.gets_to_end.to_s).to_s
        buffer.close
      rescue
        # silently ignore files we could not hash
      else
        if all_hashes[hash]?
          all_hashes[hash] += [file]
        else
          all_hashes[hash] = [file]
        end
      end
    end
    all_hashes.each do |hash, files|
      if files.size > 1
        files.each do |file|
          if duplicate_hashes[hash]?
            duplicate_hashes[hash] += [file]
          else
            duplicate_hashes[hash] = [file]
          end
        end
      end
    end
    dup_groups, dup_files = get_summary duplicate_hashes
    puts "#{dup_files} duplicates found".colorize :green
    duplicate_hashes
  end

  # Writes file names of duplicate files to an output file
  def Dedup.write_to_file(hashes, options)
    print "Step 5/5: Writing results to output file          "
    buffer = String::Builder.new
    buffer << "Duplicate files\n"
    hashes.each do |hash, files|
      buffer << "Duplicate Group (hash = #{hash}):\n"
      files.each do |file|
        buffer << "   ==> #{file}\n"
      end
      buffer << "\n"
    end

    begin
      out_file = File.open options.out_file, "w"
      File.write options.out_file, buffer.to_s
      out_file.close
    rescue
      print_error_message "Fatal: Could not write to file '#{options.out_file}'", true
    else
      puts "saved to '#{options.out_file}'".colorize :green
    end
  end

  # Helper function. Returns summary of file analysis
  def Dedup.get_summary(hashes)
    dup_groups = 0
    dup_files = 0
    hashes.each do |hash, files|
      dup_groups += 1
      dup_files += files.size
    end
    [dup_groups, dup_files]
  end

  # Helper function: Prints error message
  # and optionally exits the program
  def Dedup.print_error_message(message, exit?)
    puts message.colorize :red
    exit 1 if exit?
  end

  # ### MAIN PROGRAM ###

  # Get command line options
  options = OptParse::Options.new
  options = OptParse.parse_options options

  # Track time
  time = Time.now

  # Main processing logic
  file_list = get_from_fs options
  file_list = filter_by_file_type file_list, options
  file_list = filter_by_size file_list
  hashes = find_dups_by_hash file_list
  write_to_file hashes, options

  # Print summary
  dup_groups, dup_files = get_summary hashes
  time = Time.now - time
  puts "\nSummary".colorize :green
  puts "Duplicate groups : #{dup_groups}"
  puts "Duplicate files  : #{dup_files}"
  printf "Analysis completed in %02dm %02ds\n", time.minutes, time.seconds

  # ### END MAIN PROGRAM ###

end
