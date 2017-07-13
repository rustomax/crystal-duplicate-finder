# crystal-duplicate-finder

Command line utility written in [Crystal](https://crystal-lang.org/) to find duplicate files. This program does not delete any files. It generates a list of duplicates in a specific directory (use `-d` command line switch) for you to review and deal with them as you see fit.

## Compile and Run

> Currently Crystal only supports \*nix operating systems, including Linux and OSX. There is no compiler available for Windows.

```sh
git clone https://github.com/rustomax/crystal-duplicate-finder.git
cd crystal-duplicate-finder
crystal deps
crystal build src/cdf.cr -o cdf --release
./cdf [arguments]
```

## Usage

```
command [arguments]
-d path, --dir path         Dir where to search for duplicates (default = current dir)
-o file, --output file      Output file (default = report.out)
                            Paths for -d and -o can be relative or absolute
-p regex, --pattern regex   Search pattern (default = search all files)
                            ex: -p "*.txt" search text files
                            ex: -p "*.{doc*,ppt*,xls*}" search MS Office files
-z,         --zero          Include zero-length files in analysis (disabled by default)
-n,         --hidden        Include hidden files in analysis (disabled by default)
-h,         --help          Show this help
```

## Sample run

> Recursively list all files in the directory `test_files` including zero-length (`-z`) and hidden (`-n`) files and save the results in `report.out`

```
$ ./cdf -d test_files -n -z -o report.out

Step 1/5: Getting the list of files               8 total files
Step 2/5: Narrowing down the list (by options)    7 candidates found
Step 3/5: Narrowing down the list (by size)       5 candidates found
Step 4/5: Identifying duplicates (may take a bit) 4 duplicates found
Step 5/5: Writing results to output file          saved to 'report.out'

Summary
Duplicate groups : 2
Duplicate files  : 4
Analysis completed in 00m 00s

$ cat report.out
Duplicate files
Duplicate Group (hash = F5513387824453638074):
   ==> test_files/.hidden_file
   ==> test_files/a_subdir/file4.dat

Duplicate Group (hash = F15935516853591187496):
   ==> test_files/file1.txt
   ==> test_files/file3d.txt
```

## Contributing

1. Fork it ( https://github.com/rustomax/crystal-duplicate-finder/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [[rustomax]](https://github.com/rustomax) Max Skybin - creator, maintainer
