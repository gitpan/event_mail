#!perl
#!
#! This script reads the event log and emails the results
#!

use Win32::EventLog;
use Net::SMTP;

$CONFIG= shift;
$DEBUG = shift || 0;

unless ($CONFIG)
{
    print '
event_mail  Version 1.0
*** Syntax: event_mail config_file {DEBUG}

(C) 2001 Robert Eden, ADC Telecommunications, rmeden@yahoo.com
No Warranty expressed or implied.
This script may be distributed under the same terms as Perl itself.

This program emails changes to the NT event log to a list
of users in a config file.

**********************************************************************
** If you use this script, why not drop me an email to say thanks!! **
**********************************************************************

Config File Format
    # right of a # are comments
    MACHINE         computername        # machine name of eventlog (optional)
    MAILRELAY       address             # SMTP host to relay mail
    MAILHOST        address             # host name of machine sending email (if RELAY requires it)
    MAILTO          user@host user@host # space separated addresses
    MAILFROM        user@host           # for errors
    MAILSUBJ        subject             # subject for email (optional)
    SKIPINFO        1                   # skips info messages         
    FILTER_IN       regexp              # filters in messages
    FILTER_OUT      regexp              # filters out messages         
    FILTER_OUT      regexp2             # 2nd filter expression 

';
}

$SKIPINFO = 0;
$MAILHOST = "";
@FILTER_IN = ();
@FILTER_OUT= ();
read_config() or die "Can't open config file";
$MACHINE  = $ENV{COMPUTERNAME} unless $MACHINE;
$MAILSUBJ = "NT event log entries from $MACHINE\n" unless $MAILSUBJ;

#
# phase 1, build output file
#
open(OUTFILE,">$$.tmp") or die "Can't open $$.tmp output file";

$reccount=0;
foreach $log ("System","Security","Application")
{
    print "About to open $MACHINE $log\n" if $DEBUG;

    print OUTFILE "====== \\\\$MACHINE\\$log\n";
    print "About to process $log on $MACHINE\n" if $DEBUG;
    $handle=Win32::EventLog->new($log, $MACHINE) or die "Can't open $log on $MACHINE\n";
    $handle->GetNumber($num) or die "Can't get number of EventLog records\n";
    $handle->GetOldest($min) or die "Can't get number of oldest EventLog record\n";
    $max = $min + $num -1;

    $cur = $LAST{$log} || $max - 10;       # first time? just send 10 records
    $cur = $min  if ($cur < $min  );        # deal with lost records
    $cur = $min  if ($cur > $max+1);        # deal with reset eventlog
    print "Eventlog: (min,cur,max)  $min,$cur,$max\n" if $DEBUG;

#
# loop through records
#
    while ($cur <= $max)
    {
        $handle->Read(EVENTLOG_FORWARDS_READ|EVENTLOG_SEEK_READ, $cur, $hashRef)
                or die "Can't read EventLog entry #$cur\n";

        $cur++;

        next if (($hashRef -> {EventType}==4) and $SKIPINFO);

        if ($DEBUG > 1)
        {
             foreach $_ (sort keys %$hashRef )
             {
                 printf "%20s <%s>\n",$_,$hashRef -> {$_};
             }
        }
        print "About to execute getmessage for $cur " if $DEBUG > 1;
        Win32::EventLog::GetMessageText($hashRef) if length($hashRef -> {DATA});
        print " ok\n" if $DEBUG >1 ;
        
        @date=localtime( $hashRef -> {TimeGenerated} );
        $date[4]++;
        $date[5] = $date[5] % 100;
        $mmdd=sprintf("%02d%02d%02d",@date[5,4,3]);
        $time=sprintf("%02d%02d%02d",@date[2,1,0]);
        $er     = $hashRef -> {EventType} || "";
        $source = $hashRef -> {Source} || "";
        $desc   = $hashRef -> {Message} || $hashRef -> {Strings} || "";
        $desc   =~  s/\s/ /g;

#
# filter in
#
	$hit=0;
	$hit=1  unless @FILTER_IN;
	foreach $regex (@FILTER_IN)
	{
	    $hit=1 if $desc   =~ /$regex/;
	    $hit=1 if $source =~ /$regex/;
	    last if $hit;
        }
        next unless $hit;

#
# FILTER_out
#
	foreach $regex (@FILTER_OUT)
	{
	    $hit=0 if $desc   =~ /$regex/;
	    $hit=0 if $source =~ /$regex/;
	    last unless $hit;
        }
        next unless $hit;

    write OUTFILE;
    $reccount++;

    } # rec loop
    $LAST{$log}=$cur;
} #log_loop;
close OUTFILE;

#
# record format
#
format OUTFILE=
@<<<<< @<<<<< @< @<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$mmdd, $time, $er,$source,    $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                             $desc
~+                         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<......
                             $desc
.

#
# phase II, mail file
#
#die "stop here\n";
if ($reccount)
{
        print localtime()." sending $reccount records\n";
        $smtp = new Net::SMTP($MAILRELAY,
                              Debug => $DEBUG,
                              Hello => $MAILHOST,
                              );

        die "Can't open SMTP connection to $MAILRELAY\n" unless $smtp;
        
        $smtp->mail($MAILFROM);
        foreach (@MAILTO)
        {
            $smtp->to($_);
        }

        $smtp->data();
        $smtp->datasend("From: Eventlog_mail <$MAILFROM>\n");
        $smtp->datasend("To: @MAILTO\n");
        $smtp->datasend("Reply-to:  $MAILFROM\n");
        $smtp->datasend("Errors-to: $MAILFROM\n");
        $smtp->datasend("Subject: $MAILSUBJ\n");
        $smtp->datasend("\n");
        
        open(OUTFILE,"$$.tmp") or die "Can't reopen output file";
        while (<OUTFILE>)
        {
           $smtp->datasend($_);
        }
        $smtp->dataend();
        close OUTFILE;
        &save_config() unless $DEBUG;

} # mail file

#
# cleanup
#
unlink "$$.tmp" unless $DEBUG;


exit 0;


#
# read config file
#
sub read_config
{
    open(INFILE,$CONFIG) or die "Can't read config file $CONFIG\n";
    while (<INFILE>)
    {
        push @CONFIG,$_;
        s/#.*//g;  # remove comments
        s/^\s+//g; # remove leading spaces
        next unless length($_);
        @_ = split();
        $cmd = uc(shift @_);
        if ($cmd eq "MAILRELAY")
        {
            $MAILRELAY=shift;
        }
        elsif ($cmd eq "MAILHOST")
        {
            $MAILHOST=shift;
        }
        elsif ($cmd eq "MAILTO")
        {
            @MAILTO=@_;
        }
        elsif ($cmd eq "MACHINE")
        {
            $MACHINE=shift;
        }
        elsif ($cmd eq "MAILFROM")
        {
            $MAILFROM = shift;
        }
        elsif ($cmd eq "MAILSUBJ")
        {
            $MAILSUBJ = join(" ",@_);
        }
        elsif ($cmd eq "LAST")
        {
            $LAST{$_[0]}=$_[1];
        }
        elsif ($cmd eq "SKIPINFO")
        {
            $SKIPINFO = shift;
        }
        elsif ($cmd eq "FILTER_IN")
        {
            push @FILTER_IN, "@_" ;
        }
        elsif ($cmd eq "FILTER_OUT")
        {
            push @FILTER_OUT, "@_" ;
        }
        else
        {
            die "Unknown config file item $cmd\n";
        }
    } # infile loop
    close INFILE;
} # read config file

#
# save config file
#
sub save_config
{
    open(INFILE,">$CONFIG") or die "Can't write config file $CONFIG\n";
    foreach (@CONFIG)
    {
        $orig=$_;
        s/#.*//g;  # remove comments
        s/^\s+//g; # remove leading spaces
        @_ = split();
        $cmd = uc(shift @_);
        if ($cmd eq "LAST")
        {
            print INFILE "LAST $_[0] $LAST{$_[0]}\n";
            delete $LAST{$_[0]};
        }
        else
        {
            print INFILE $orig;
        }
    } # infile loop
#
# handle any extra logs
#
    foreach $log (sort keys %LAST)
    {
       print INFILE "LAST $log $LAST{$log}\n";
    }
    close INFILE;
} # save config file

