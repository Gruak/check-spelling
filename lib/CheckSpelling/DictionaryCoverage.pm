#! -*-perl-*-

package CheckSpelling::DictionaryCoverage;

our $VERSION='0.1.0';
use File::Basename;
use Encode qw/decode_utf8 encode FB_DEFAULT/;
use CheckSpelling::Util;

my $hunspell;

sub entry {
  my ($name) = @_;
  my $handle;
  unless (open ($handle, '<:utf8', $name)) {
    print STDERR "Couldn't open dictionary `$name` (dictionary-not-found)\n";
    return 0;
  }
  return {
    name => $name,
    handle => $handle,
    word => "0",
    uniq => 0,
    covered => 0
  }
}

sub hunspell_entry {
  my ($name) = @_;
  unless (open ($handle, '<:utf8', $name)) {
    print STDERR "Couldn't open dictionary `$name` (dictionary-not-found)\n";
    return 0;
  }
  my $lines = <$handle>;
  chomp $lines;
  close $handle;
  my $aff = $name;
  my $encoding;
  $aff =~ s/dic$/aff/;
  if (open AFF, '<', $aff) {
    while (<AFF>) {
      next unless /^SET\s+(\S+)/;
      $encoding = $1 if ($1 !~ /utf-8/i);
      last;
    }
    close AFF;
  }
  my %map;
  return {
    name => $name,
    handle => undef,
    encoding => $encoding,
    engine => Text::Hunspell->new($aff, $dict),
    coverage => \%map,
    uniq => 0,
    lines => $lines
  }
}

sub main {
  my ($check, @dictionaries) = @_;
  my @files;
  my $unknown_words;
  unless (open($unknown_words, '<:utf8', $check)) {
    print STDERR "Could not read $check\n";
    return 0;
  }

  our $hunspell;
  for my $name (@dictionaries) {
    if ($name =~ /\.dic$/) {
      unless ($hunspell) {
        unless (eval 'use Text::Hunspell; 1') {
          print STDERR "Could not load Text::Hunspell for \`$name\` (hunspell-unavailable)\n";
          next;
        }
        $hunspell = 1;
      }
      push @files, hunspell_entry($name);
    } else {
      push @files, entry($name);
    }
  }

  my @results=@files;
  while (@files) {
    last if eof($unknown_words);
    my $unknown = <$unknown_words>;
    last if ($unknown eq '');
    my @drop;
    my $uniq = -1;
    for (my $file_id = 0; $file_id < scalar @files; $file_id++) {
      my $current = $files[$file_id];
      my ($word, $handle, $engine) = (
        $current->{'word'},
        $current->{'handle'},
        $current->{'engine'},
      );
      while ($word ne '' && $word lt $unknown) {
        if ($engine) {
          my $token_encoded = defined $hunspell_dictionary->{'encoding'} ?
            encode($hunspell_dictionary->{'encoding'}, $unknown) : $unknown;
          if ($engine->check($token_encoded)) {
            my $stem = $engine->stem($word);
            $current->{'coverage'}->{$stem} = 1;
            if ($uniq > -1) {
              $uniq = -2;
            } else {
              $uniq = $file_id;
            }
          }
          next;
        }
        if (eof $handle) {
          $word = '';
        } else {
          $word = <$handle>;
        }
      }
      if ($word eq $unknown) {
        ++$current->{"covered"};
        if ($uniq > -1) {
          $uniq = -2;
        } else {
          $uniq = $file_id;
        }
        if (eof $handle) {
          $word = '';
        } else {
          $word = <$handle>;
        }
      }
      $current->{"word"} = $word;
      if ($word eq '') {
        push @drop, $file_id;
      }
    }
    if ($uniq > -1) {
      my $current = $files[$uniq];
      ++$current->{"uniq"};
    }
    if (@drop) {
      for $file_id (reverse @drop) {
        splice @files, $file_id, 1;
      }
    }
  }
  my $re=CheckSpelling::Util::get_file_from_env('aliases', '');
  my $extra_dictionaries = CheckSpelling::Util::get_file_from_env('extra_dictionaries', '');
  @dictionaries=split /\n/, $extra_dictionaries;
  for (my $file_id = 0; $file_id < scalar @results; $file_id++) {
    my $current = $results[$file_id];
    my $covered = $current->{'coverage'} ? scalar(keys %{$current->{'coverage'}}) : $current->{"covered"};
    next unless $covered;

    my $name = $current->{"name"};
    my @pretty = grep m{[:/]$name}, @dictionaries;
    unless (@pretty) {
      $name = basename($name);
      @pretty = grep m{[:/]$name}, @dictionaries;
    }
    $name = $pretty[0] if @pretty;

    my $uniq = $current->{"uniq"};
    my $handle = $current->{"handle"};
    my $lines;
    if ($handle) {
      my $word = $current->{"word"};
      $word = <$handle> while !eof($handle);
      $lines = $handle->input_line_number();
    } else {
      $lines = $handle->{'lines'};
    }

    local $_ = $name;
    eval $re;
    my $url = $_;

    my $name_without_spaces = $name;
    $name_without_spaces =~ s/\s+/_/g;

    my $unique = '';
    if ($uniq) {
      $unique = " ($uniq uniquely)";
    } else {
      $uniq = 0;
    }
    print "$covered-$lines-$uniq-$name_without_spaces [$name]($url) ($lines) covers $covered of them$unique\n";
  }
}

1;
