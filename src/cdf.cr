require "./optparse"
require "colorize"
require "murmur3"

class CDF
  alias FileList = Array(String)
  alias Sizes = Hash(UInt64, Array(String))
  alias Hashes = Hash(String, Array(String))

  enum MessageType
    Status
    StatusNewLine
    Success
    Error
  end

  def initialize(file_list : FileList = FileList.new,
                 options : OptParse::Options = OptParse::Options.new,
                 hashes : Hashes = Hashes.new,
                 start_time : Time = Time.now)
    @file_list = file_list
    @options = options
    @hashes = hashes
    @start_time = start_time
  end

  # Parses command line options
  def get_options
    @options = OptParse.parse_options @options
  end

  # Returns file list matching specific pattern from filesystem
  def get_files_from_fs
    print_message "\nStep 1/5: Getting the list of files               "
    @file_list = FileList.new
    path = @options.root_dir + @options.pattern
    begin
      @file_list = Dir[path]
    rescue
      print_message "Fatal: Could not read '#{@options.root_dir}'", MessageType::Error
      exit 1
    else
      print_message "#{@file_list.size} total files and directores", MessageType::Success
    end
  end

  # Narrows down the list of possible duplicate candidates
  # by filtering out files based on file type and user-selected options
  # i.e hidden or zero-length files, directories, etc.
  def filter_by_type
    print_message "Step 2/5: Narrowing down the list (by file type)  "
    @file_list.reject! do |file|
      begin
        delete_file? = !File.file?(file) || File.symlink?(file) ||
                       (File.size(file) == 0 && !@options.zero_len) ||
                       (File.basename(file)[0] == '.' && !@options.hidden)
      rescue
        true # stop processing files we could not stat
      else
        delete_file?
      end
    end

    print_message "#{@file_list.size} candidates found", MessageType::Success
  end

  # Narrows down the list of possible duplicate candidates
  # by filtering out files with unque sizes
  def filter_by_size
    print_message "Step 3/5: Narrowing down the list (by size)       "
    sizes = Sizes.new
    @file_list.each do |file|
      begin
        size = File.size file
      rescue
        # silently ignore files we could not get sizes for
      else
        sizes[size] = sizes[size]? ? sizes[size] + [file] : [file]
      end
    end
    @file_list = sizes
      .select { |size, files| files.size > 1 }
      .map { |size_files| size_files[1] }
      .flatten
    print_message "#{@file_list.size} candidates found", MessageType::Success
  end

  # Hash all files in the file_list and return a Hash with duplicates only
  def find_dups_by_hash
    print_message "Step 4/5: Identifying duplicates (may take a bit) "
    @file_list.each do |file|
      begin
        # TODO: Find more efficient way to do this for large files
        buffer = File.new file
        hash = "F" + Murmur3.h1(buffer.gets_to_end.to_s).to_s
        buffer.close
      rescue
        # silently ignore files we could not hash
      else
        @hashes[hash] = @hashes[hash]? ? @hashes[hash] + [file] : [file]
      end
    end
    @hashes.reject! { |hash, files| files.size < 2 }
    dup_groups, dup_files = get_summary
    print_message "#{dup_files} duplicates found", MessageType::Success
  end

  # Writes file names of duplicate files to an output file
  def write_to_file
    print_message "Step 5/5: Writing results to output file          "
    buffer = String::Builder.new
    buffer << "Duplicate files\n"
    @hashes.each do |hash, files|
      buffer << "Duplicate Group (hash = #{hash}):\n"
      files.each do |file|
        buffer << "   ==> #{file}\n"
      end
      buffer << "\n"
    end

    begin
      out_file = File.open @options.out_file, "w"
      File.write @options.out_file, buffer.to_s
      out_file.close
    rescue
      print_message "Fatal: Could not write to file '#{@options.out_file}'", MessageType::Error
      exit 1
    else
      print_message "saved to '#{@options.out_file}'", MessageType::Success
    end
  end

  # Prints analysis summary on-screen
  def print_summary
    if !@options.quiet
      dup_groups, dup_files = get_summary
      elapsed_time = Time.now - @start_time
      puts "\nSummary".colorize :green
      puts "Duplicate groups : #{dup_groups}"
      puts "Duplicate files  : #{dup_files}"
      printf "Analysis completed in %02dm %02ds\n", elapsed_time.minutes, elapsed_time.seconds
    end
  end

  # Helper function. Returns summary of file analysis
  def get_summary
    dup_groups = @hashes.size
    dup_files = @hashes.reduce(0) { |acc, hash_files| acc + hash_files[1].size }
    [dup_groups, dup_files]
  end

  # Helper function: Prints various message types and optionally quits
  def print_message(message_text, message_type = MessageType::Status)
    if !@options.quiet
      print case message_type
      when MessageType::Success
        (message_text + "\n").colorize :green
      when MessageType::Status
        message_text
      when MessageType::StatusNewLine
        message_text + "\n"
      when MessageType::Error
        (message_text + "\n").colorize :red
      end
    end
  end
end

# ### MAIN PROGRAM ###
cdf = CDF.new
cdf.get_options
cdf.get_files_from_fs
cdf.filter_by_type
cdf.filter_by_size
cdf.find_dups_by_hash
cdf.write_to_file
cdf.print_summary
# ### END MAIN PROGRAM ###
