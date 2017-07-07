require "option_parser"
require "colorize"

module OptParse
  struct Options
    property root_dir, out_file, pattern, zero_len, hidden

    def initialize(@root_dir : String = ".",
                   @out_file : String = "report.out",
                   @pattern : String = "/**/*",
                   @zero_len : Bool = false,
                   @hidden : Bool = false)
    end
  end

  def OptParse.usage_message
    puts <<-HELPMESSAGE
    \nIdentify duplicate files in a directory
    Usage: command [arguments]\n
    -d path, --dir path         Dir where to search for duplicates (default = current dir)
    -o file, --output file      Output file (default = duplicates.out)
                                Paths for -d and -o can be relative or absolute
    -p regex, --pattern regex   Search pattern (default = search all files)
                                ex: -p \"*.txt\" search text files
                                ex: -p \"*.{doc*,ppt*,xls*}\" search MS Office files
    -z,         --zero          Include zero-length files in analysis (disabled by default)
    -n,         --hidden        Include hidden files in analysis (disabled by default)
    -h,         --help          Show this help
    HELPMESSAGE
  end

  # Option parser
  def OptParse.parse_options(options)
    begin
      OptionParser.parse! do |parser|
        parser.on("-d root_dir", "--dir root_dir", "Directory to scan") do |opt_dir|
          options.root_dir = opt_dir
        end

        parser.on("-o out_file", "--out out_file", "Output file") do |opt_out|
          options.out_file = opt_out
        end

        parser.on("-p pattern", "--pat pattern", "Search pattern") do |opt_pat|
          options.pattern = "/**/" + opt_pat if !opt_pat.to_s.empty?
        end

        parser.on("-z", "--zero", "Include zero-length files in analysis") do |opt_zero|
          options.zero_len = opt_zero.to_s.empty?
        end

        parser.on("-n", "--hidden", "Include hidden files in analysis") do |opt_hidden|
          options.hidden = opt_hidden.to_s.empty?
        end

        parser.on("-h", "--help", "Show this help") do
          usage_message
          exit 0
        end

        parser.unknown_args() do |uargs|
          if uargs != [] of String
            raise Exception.new("Invalid option")
          end
        end
      end
    rescue exception
      puts "Error: #{exception}".colorize(:red)
      usage_message
      exit 1
    end

    options
  end
end
