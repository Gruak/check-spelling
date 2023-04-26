#!/usr/bin/env perl
open WARNINGS, ">>:encoding(UTF-8)", $ENV{early_warnings};
my $file = $ARGV[0];
open FILE, "<:encoding(UTF-8)", $file;
$/ = undef;
my $content = <FILE>;
close FILE;
open FILE, ">:encoding(UTF-8)", $file;

my $first_end = undef;
my $messy = 0;
$. = 0;
while ($content =~ s/([^\r\n\x0b\f\x85\x2028\x2029]*)(\r\n|\n|\r|\x0b|\f|\x85|\x2028|\x2029)//m) {
    ++$.;
    my ($line, $end) = ($1, $2);
    unless (defined $first_end) {
        $first_end = $end;
    } elsif ($end ne $first_end) {
        print WARNINGS "$file:$.:$-[0] ... $+[0], Warning - Entry has inconsistent line ending. (unexpected-line-ending)\n";
    }
    if ($line =~ '"/^[${expected_chars}]*([^${expected_chars}]+)/"') {
        $column_range="$-[1] ... $+[1]";
        unless ($line =~ '"/^${comment_char}/"') {
        print WARNINGS "$file:$.:$column_range, Warning - Ignoring entry because it contains non alpha characters. (non-alpha-in-dictionary)\n";
        }
        $line = "";
    }
    print FILE "$line\n";
}
print FILE $content;
close WARNINGS;
