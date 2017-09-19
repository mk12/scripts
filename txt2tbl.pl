#!/usr/bin/perl

#####################################################################
##
## txt2tbl.pl [ 0.01 ]
##
## + perl script than turns minimally marked up text files into 
##   formatted ascii tables
##
## + for usage information, execute the script
##
## Author:
##
##   Dave Pettypiece
##   davidp@canada.com
##   July 20, 1999
## 
#####################################################################

if ( $#ARGV + 1 <= 0 )
{
    print "\nUsage: txt2tbl.pl FILENAME W(1) .. W(n)\n"; 
    print "\n";
    print "Where:\n";
    print "\n";
    print "    W(1) .. W(n) are integers specifying the widths\n";
    print "    of n columns, and each W(i) is larger than the widest\n"; 
    print "    word to be put in the ith column.\n";
    print "\n";
    print "    FILENAME must be a text file where each line is \n"; 
    print "    started with a \"+\" and represents a cell in the\n";
    print "    table to be generated\n";
    print "\n";
    print "Example:\n";
    print "\n";
    print "    Calling: txt2tbl.pl infile 10 10 10 \n";
    print "    where the file \"infile\" contains:\n";
    print "    \n";
    print "    +Row Number\n";
    print "    +Name\n";
    print "    +Color\n";
    print "    +1\n";
    print "    +fred\n";
    print "    +green or brown\n";
    print "    +2\n";
    print "    +mary\n";
    print "    +pink\n";
    print "    \n";
    print "    will generate the following 3x3 table to STDOUT:\n";
    print "    \n";
    print "    +------------+------------+------------+\n";
    print "    | Row Number | Name       | Color      |\n";
    print "    +------------+------------+------------+\n";
    print "    | 1          | fred       | green or   |\n";
    print "    |            |            | brown      |\n";
    print "    +------------+------------+------------+\n";
    print "    | 2          | mary       | pink       |\n";
    print "    +------------+------------+------------+\n";
    print "    \n";
    print "Bugs:\n";
    print "    \n";
    print "    Cells can be specified with multiple lines where only\n";
    print "    the first line is started with a \"+\", except for the last\n";
    print "    cell of each row.\n";
    print "    \n";
}
else
{
    open INFILE, $ARGV[0] or die "Error opening file\n";

    my $horz_line = "+";        ## the horizontal line
    my $num_cols = $#ARGV;      ## number of columns
    my @col_widths;             ## array of column widths
    my @cur_lines;              ## array of current lines

    ##
    ## build up array of column widths
    ##

    for ( $i = 0; $i < $num_cols; $i++ )
    {   
        $col_widths[$i] = $ARGV[$i + 1];
    }

    ##
    ##  build up horizontal line
    ## 

    for ( $i = 0; $i < $num_cols; $i++ )
    {   
        $horz_line .= "-" x ( $col_widths[$i] + 2 ) . "+";
    }


    ##
    ##  process the input file
    ## 

    $counter = 0;

    while ( <INFILE> )
    {

        ## build up array of current strings

        if ( $_ =~ /^\+/ )
        {   
            $_ =~ s/^.//;
            chomp $_;
            $cur_lines[$counter] = $_;
            $counter++;
        }
        else
        {
            chomp $_;
            $cur_lines[$counter - 1] .= " " . $_;
        }
  

        ## the list has been built, so process it and reset counter

        if ( $counter == $num_cols )
        {

            print "\n" . $horz_line;

            @line_chunks;
            $done = 0;

            while ( !$done ) 
            {
                    
                print "\n|";

                for ( $i = 0; $i < $num_cols; $i++ )
                {   
                    $cur_lines[$i] =~ /^([^\s]*)/; 
                    $x = $1;
                    while ( ( length($line_chunks[$i]) + length($x) - 1 ) < $col_widths[$i] )
                    {
                        $line_chunks[$i] .= " " . $1;
                        $cur_lines[$i] =~ s/^[^\s]*[\s]*//; 
                        $cur_lines[$i] =~ /^([^\s]*)/; 
                        $x = $1;
                    }
                    print $line_chunks[$i] . " " x ($col_widths[$i] - length($line_chunks[$i]) + 2) . "|";

                    $line_chunks[$i] = "";
                }

                $done = 1;
                for ( $i = 0; $i < $num_cols; $i++ )
                {   
                    if ( $cur_lines[$i] !~ /^\s*$/ )
                    {
                        $done = 0;
                        break;
                    }
                }
                
            }


            $counter = 0;
        }
    }

    print "\n" . $horz_line . "\n";
}