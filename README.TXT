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

