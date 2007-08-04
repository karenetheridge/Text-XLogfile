#!perl
package Text::XLogfile;
use strict;
use warnings;
use base 'Exporter';
use Carp;

our @EXPORT_OK = qw(read_xlogfile parse_xlogline write_xlogfile make_xlogline);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

=head1 NAME

Text::XLogfile - reading and writing xlogfiles

=head1 VERSION

Version 0.02 released 04 Aug 07

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

    use Text::XLogfile ':all';

    my @scores = read_xlogfile("scores.xlogfile");
    for (@scores) { $_->{player} = lc $_->{player} }
    write_xlogfile(\@scores, "scores.xlogfile.new");

    my $xlogline = make_xlogline($scores[0], -1);
    my $score = parse_xlogline($xlogline);
    print "First place: $score->{player}\n";
    print "$xlogline\n";

=head1 xlogfile format

'xlogfile' is a simple line-based data format. An xlogfile is analogous to an
array of hashes. Each line corresponds to a hash. A sample xlogline looks like:

    name=Eidolos:ascended=1:role=Wiz:race=Elf:gender=Mal:align=Cha

This obviously corresponds to the following hash:

    {
        ascended => 1,
        align    => 'Cha',
        name     => 'Eidolos',
        race     => 'Elf',
        role     => 'Wiz',
        gender   => 'Mal',
    }

xlogfile supports no quoting. Keys and values may be any non-colon characters.
The first C<=> separates the key from the value (so in C<a=b=c>, the key is
C<a>, and the value is C<b=c>. Colons are usually transliterated to
underscores. Like a Perl hash, if multiple values have the same key, later
values will overwrite earlier values. Here's something resembling the actual
grammar:

    xlogline <- field [: field]*
    field    <- key=value
    key      <- [^:=\n]*
    value    <- [^:\n]*

xlogfiles are used in the NetHack community. CSV is too ill-defined. XML is too
heavyweight. YAML is multiline. JSON is feasible, but we've already chosen
xlogfile.

=cut

=head1 FUNCTIONS

=head2 read_xlogfile FILENAME => ARRAY OF HASHREFS

Takes a file and parses it as an xlogfile. If any IO error occurs in reading
the file, an exception is thrown. If any error occurs in parsing an xlogline,
then an empty hash will be returned in its place.

=cut

sub read_xlogfile
{
    my $filename = shift;
    my @entries;

    open my $handle, '<', $filename
        or Carp::croak "Unable to read $filename for reading: $!";

    while (<$handle>)
    {
        push @entries, parse_xlogline($_) || {};
    }

    close $handle
        or Carp::croak "Unable to close filehandle: $!";

    return @entries;
}

=head2 parse_xlogline STRING => HASHREF

Takes a string and attempts to parse it as an xlogline. If a parse error
occurs, C<undef> is returned. The only actual parse error is if there is a
field with no C<=>. Lacking C<:> does not invalidate an xlogline; the entire
line is a single field.

=cut

sub parse_xlogline
{
    my $input = shift;
    my $output = {};

    chomp $input;

    my @fields = split /:/, $input;

    for my $field (@fields)
    {
        my ($key, $value) = split /=/, $field;
        return if !defined($value); # no = found

        $output->{$key} = $value;
    }

    return $output;
}

=head2 write_xlogfile ARRAYREF OF HASHREFS, FILENAME

Writes an xlogfile to FILENAME. If any IO error occurs, it will throw an
exception. If any error in making the xlogline occurs (see the documentation
of C<make_xlogline>), it will automatically be corrected.

Returns no useful value.

=cut

sub write_xlogfile
{
    my $entries = shift;
    my $filename = shift;

    open my $handle, '>', $filename
        or Carp::croak "Unable to open '$filename' for writing: $!";

    for my $entry (@$entries)
    {
        print {$handle} make_xlogline($entry, 1), "\n"
            or Carp::croak "Error occurred during print: $!";
    }

    close $handle
        or Carp::croak "Unable to close filehandle: $!";

    return;
}

=head2 make_xlogline HASHREF[, INTEGER] => STRING

Takes a hashref and turns it into an xlogline. The optional integer controls
what the function will do when it faces one of three potential errors. A value
of one will correct the error. A value of zero will cause an exception (this is
the default). A value of negative one will ignore the error which is very
likely to cause problems when you read the xlogfile back in (you may want this
when know for sure that your hashref is fine).

The potential problems it will fix are:

=over 4

=item Keys with C<=>

If a key contains C<=>, then it will not be read back in correctly. Consider
the following field:

    foo=bar=baz

The interpretation of this will always be C<'foo' = 'bar=baz'>. Therefore a
key with C<=> is erroneous. If error correcting is enabled, any C<=> in a key
will be turned into an underscore, C<_>.

=item Keys or values with C<:>

Because colons separate fields and there's no way to escape colons, any colons
in a key or value is an error. If error correcting is enabled, any C<:> in a
key or value will be turned into an underscore, C<_>.

=item Keys or values with C<\n>

xlogfiles are a line-based format, so neither keys nor values may contain
newlines, C<\n>. If error correcting is enabled, any C<\n> in a key or value
will be turned into a single space character.

=back

=cut

sub make_xlogline
{
    my $input = shift;
    my $correct = shift;
    my @fields;

    # code duplication is bad, but not that much is being duplicated
    if (!$correct)
    {
        while (my ($key, $value) = each %$input)
        {
            if ($key =~ /([=:\n])/)
            {
                my $bad = $1; $bad = $bad eq "\n" ? "newline" : "'$bad'";
                $key =~ s/\n/\\n/;
                Carp::croak "Key '$key' contains invalid character: $bad.";
            }

            if ($value =~ /([:\n])/)
            {
                my $bad = $1; $bad = $bad eq "\n" ? "newline" : "'$bad'";
                $key =~ s/\n/\\n/; $value =~ s/\n/\\n/;
                Carp::croak "Value '$value' (of key '$key') contains invalid character: $bad.";
            }

            push @fields, "$key=$value";
        }
    }
    elsif ($correct == -1)
    {
        while (my ($key, $value) = each %$input)
        {
            push @fields, "$key=$value";
        }
    }
    elsif ($correct == 1)
    {
        while (my ($key, $value) = each %$input)
        {
            $key   =~ y/\n:=/ __/;
            $value =~ y/\n:/ _/;
            push @fields, "$key=$value";
        }
    }

    return join ':', @fields;
}

=head1 AUTHOR

Shawn M Moore, C<< <sartak at gmail.com> >>

=head1 BUGS

No known bugs.

Please report any bugs through RT: email 
C<bug-text-xlogfile at rt.cpan.org>, or browse to
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Text-XLogfile>.

=head1 SUPPORT

You can find this documentation for this module with the perldoc command.

    perldoc Text::XLogfile

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Text-XLogfile>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Text-XLogfile>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Text-XLogfile>

=item * Search CPAN

L<http://search.cpan.org/dist/Text-XLogfile>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Aardvark Joe for coming up with the xlogfile format. It's much
better than NetHack's default logfile.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Shawn M Moore.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

