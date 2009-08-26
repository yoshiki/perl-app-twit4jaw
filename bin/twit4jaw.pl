#!/usr/local/bin/perl

use strict;
use warnings;
use 5.008001;
use Daemonise;
use Getopt::Long;
use Pod::Usage;
use Path::Class;
use JSON::Syck ();
use Encode ();
use Encode::JavaScript::UCS;
use List::Util qw( shuffle );
use LWP::Simple ();
use Net::Twitter::Lite;

our $VERSION = 0.01;
our $TARGET_USER_TIMELINE_URL_FORMAT
    = 'http://twitter.com/statuses/user_timeline.json?screen_name=%s&count=1';

GetOptions( \my %opts, 'version', 'help',
            'pid=s', 'interval=i', 'username=s', 'password=s', 'target=s', 'message|msg=s' );
pod2usage( -verbose => 1 ) if $opts{ help };
pod2usage( -verbose => 99, -sections => 'NAME|VERSION|LICENSE' ) if $opts{ version };

my $pid_file = $opts{ pid }      || '/tmp/twit4jaw.pid';
my $msg_file = $opts{ message }  || '/tmp/twit_msgs.txt';
my $interval = $opts{ interval } || 300;
my $username = $opts{ username } || undef;
my $password = $opts{ password } || undef;
my $target   = $opts{ target }   || undef;
my $command  = $ARGV[0]          || 'start';

if ( $command eq 'stop' ) {
    my $file = file( $pid_file );
    my $pid = $file->slurp;
    kill( 9, $pid );
    $file->remove;
    exit;
}
elsif ( $command eq 'start' ) {
    pod2usage( 2 ) if !$username || !$password || !$target;
    pod2usage( "$msg_file: No such file or directory." ) unless -e $msg_file;

#    Daemonise::daemonise();

    open my $fh, '>', $pid_file;
    print $fh $$;
    close $fh;

    my $last_created_at = '';
    my $last_mtime = '';
    my @messages;
    while ( 1 ) {
        # load message file if file was updated.
        if ( !length $last_mtime || $last_mtime < (stat($msg_file))[9] ) {
            my $file = file( $msg_file );
            @messages = $file->slurp( chomp => 1 );
            $last_mtime = (stat($msg_file))[9];
        }

        # get target user's timeline
        my $timeline_url = sprintf $TARGET_USER_TIMELINE_URL_FORMAT, $target;
        my $json = LWP::Simple::get( $timeline_url );
        if ( !length $json ) {
            warning "Invalid target or API limit reached: $target";
            next;
        }
        my $data = JSON::Syck::Load( $json );
        my $latest_data = $data->[0];

        # skip when first time.
        if ( length $last_created_at
             && $latest_data->{ created_at } ne $last_created_at ) {
            my $text = $latest_data->{ text };
            Encode::from_to( $text, 'JavaScript-UCS', 'utf8' );
            $text =~ s/\\//g;
            next if !length $text || $text =~ m/\@/;
            my $nt = Net::Twitter::Lite->new(
                username => $username,
                password => $password,
            );
            my $is_rt = int( rand( 2 ) );
            my @shuffled_msgs = shuffle @messages;
            my $message = $is_rt
                        ? sprintf( q{%s RT @%s: %s}, $shuffled_msgs[0], $target, $text )
                        : sprintf( q{@%s %s}, $target, $shuffled_msgs[0] );
            eval { $nt->update( Encode::decode( 'utf8', $message ) ) };
        }
        $last_created_at = $latest_data->{ created_at };
        sleep $interval;
    }
}

=head1 NAME

twit4jaw.pl - Twitter bot to read someone a lecture.

=head1 SYNOPSIS

 twit4jaw.pl --username=username --password=password --target=username [options] [start|stop]

 Options:
   --username Twitter username for bot(required)
   --password Twitter password for bot(required)
   --target   username for target(required)
   --message  message file
   --pid      pid file
   --interval retry interval
   --version  print version
   --help     brief help message

=head1 EQUIPMENT

=over 8

=item 1

Create new twitter account for bot.

=item 2

Make message file included 1 message per line for tweet.

=item 3

Execute this program!

 % twit4jaw.pl --username=bot_username --password=bot_password --target=your_username start

=back

=head1 VERSION

0.01

=head1 AUTHOR

Yoshiki Kurihara E<lt>kurihara@cpan.orgE<gt>

=head1 LICENSE

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Daemonise>, L<Getopt::Long>, L<Pod::Usage>, L<Path::Class>,
L<JSON::Syck>, L<Encode>, L<Encode::JavaScript::UCS>, L<List::Util>,
L<LWP::Simple>, L<Net::Twitter::Lite>

=cut
