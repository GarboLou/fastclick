#!/usr/local/bin/perl -w

# element2man.pl -- creates man pages from structured comments in element
# source code
# Eddie Kohler
# Robert Morris - original make-faction-html script
#
# Copyright (c) 1999 Massachusetts Institute of Technology.
#
# This software is being provided by the copyright holders under the GNU
# General Public License, either version 2 or, at your discretion, any later
# version. For more information, see the `COPYRIGHT' file in the source
# distribution.

my(%section_is_array) = ( 'h' => 1, 'a' => 1, 'page' => 1 );
my $directory;
my $section = 'n';
my(@all_outnames, %all_outsections, %class_name, %processing);

my(%processing_constants) =
    ( 'AGNOSTIC' => 'a/a', 'PUSH' => 'h/h', 'PULL' => 'l/l',
      'PUSH_TO_PULL' => 'h/l', 'PULL_TO_PUSH' => 'l/h' );
my(%processing_text) =
    ( 'a/a' => 'agnostic', 'h/h' => 'push', 'l/l' => 'pull',
      'h/l' => 'push inputs, pull outputs',
      'l/h' => 'pull inputs, push outputs',
      'a/ah' => 'agnostic, but output 1 is push' );

# find date
my($today) = '';
if (localtime =~ /\w*\s+(\w*)\s+(\d*)\s+\S*\s+(\d*)/) {
  $today = "$2/$1/$3";
}

my $prologue = <<'EOD;';
.de M
.BR "\\$1" "(\\$2)\\$3"
..
.de RM
.RB "\\$1" "\\$2" "(\\$3)\\$4"
..
EOD;
chomp $prologue;

sub nroffize ($;$$) {
  my($t, $related, $related_source) = @_;
  my($i);

  # embolden & manpageize
  if (defined $related) {
    foreach $i (@$related) {
      $t =~ s{(^|[^\w@/>])$i($|[^\w@/])}{$1<\#>$i</\#>$2}gs;
    }
  }

  # remove emboldening & manpaging on examples
  1 while ($t =~ s{^= (.*)</?[\#]>}{= $1}gm);
  
  $t =~ s/\\/\\\\/g;
  $t =~ s/^(= )?\./$1\\&./gm;
  $t =~ s/^(= )?'/$1\\&'/gm;
  $t =~ s/^\s*$/.PP\n/gm;
  $t =~ s/<i>(.*?)<\/i>/\\fI$1\\fP/ig;
  $t =~ s/<b>(.*?)<\/b>/\\fB$1\\fP/ig;
  $t =~ s/<tt>(.*?)<\/tt>/\\f(CW$1\\fP/ig;
  $t =~ s{<\#>(.*?)<\/\#>(\S*)(\s*)}{
    if ($related_source->{$1}) {
      "\n.M $1 \"$related_source->{$1}\" $2\n";
    } else {
      "\\fB$1\\fP$2$3";
    }
  }eg;
  $t =~ s{\n\.M (\S+) \"(\S+)\" \(\2\)(.*)\n}{\n.M $1 "$2" $3\n}g;
  1 while ($t =~ s/^\.PP\n\.PP\n/.PP\n/gm);
  $t =~ s/^= (.*\n)/.nf\n$1.fi\n/mg;
  $t =~ s/^\.fi\n\.nf\n//mg;
  $t =~ s/\n+/\n/sg;
  $t;
}

sub process_processing ($) {
  my($t) = @_;
  if (exists($processing_constants{$t})) {
    $t = $processing_constants{$t};
  }
  $t =~ tr/\"\s//d;
  $t =~ s{\A([^/]*)\Z}{$1/$1};
  if (exists($processing_text{$t})) {
    return $processing_text{$t};
  }
  return undef;
}

sub process_comment ($$) {
  my($t, $filename) = @_;
  my(%x, $i);

  while ($t =~ m{^=(\w+)\s*([\0-\377]*?)(?=\n=\w|\Z)}mg) {
    if ($section_is_array{$1}) {
      push @{$x{$1}}, "$2\n";
    } else {
      $x{$1} .= "$2\n";
    }
  }

  # snarf class names
  my(@classes, %classes);
  while ($x{'c'} =~ /^\s*(\w+)\(/mg) { # configuration arguments section
    push @classes, $1 if !exists $classes{$1};
    $classes{$1} = 1;
  }
  if (!@classes && $x{'c'} =~ /^\s*([\w@]+)\s*$/) {
    push @classes, $1;
    $classes{$1} = 1;
  }
  if (!@classes) {
    print STDERR "$filename: no class definitions\n    (did you forget `()' in the =c section?)\n";
    return;
  }

  # output filenames might be specified in 'page' section
  my(@outfiles) = @classes;
  my(@outsections) = ($section) x @classes;
  if ($x{'page'}) {
    @outfiles = ();
    @outsections = ();
    foreach $i (map(split(/\s+/), @{$x{'page'}})) {
      if ($i =~ /^(.*)\((.*)\)$/) {
	push @outfiles, $1;
	push @outsections, $2;
      } else {
	push @outfiles, $i;
	push @outsections, $section;
      }
    }
  }

  # open new output file if necessary
  my($main_outname);
  if ($directory) {
    $main_outname = "$directory/$outfiles[0].$outsections[0]";
    if (!open(OUT, ">$main_outname")) {
      print STDERR "$main_outname: $!\n";
      return;
    }
  }
  push @all_outfiles, $outfiles[0];
  $all_outsections{$outfiles[0]} = $outsections[0];

  # front matter
  my($classes_text) = join(', ', @classes);
  my($oneliner) = ($x{'desc'} ? $x{'desc'} : (@classes == 1 ? "Click element" : "Click elements"));
  my($outfiles_text) = join(', ', @outfiles);

  print OUT <<"EOD;";
.\\" -*- mode: nroff -*-
.\\" Generated by \`element2man.pl' from \`$filename'
$prologue
.TH "\U$outfiles_text\E" $outsections[0] "$today" "Click"
.SH "NAME"
$classes_text \- $oneliner
EOD;
  
  # prepare related
  my(@related, @srelated, %related_source, %srelated_source);
  if ($x{'a'}) {
    foreach $i (map(split(/\s+/), @{$x{'a'}})) {
      if ($i =~ /^(.*)\((.*)\)$/) {
	push @related, $1;
	$related_source{$1} = $2;
      } else {
	push @related, $i;
	$related_source{$i} = 'n';
      }
    }
  }
  @srelated = sort { length($b) <=> length($a) } (@related, @classes);
  %srelated_source = %related_source;
  map(delete $srelated_source{$_}, @classes);

  if ($x{'c'}) {
    print OUT ".SH \"SYNOPSIS\"\n";
    while ($x{'c'} =~ /^\s*(\S.*)$/mg) {
      print OUT nroffize($1, \@srelated), "\n.br\n";
    }
  }

  if (@classes == 1 && $processing{$classes[0]}) {
    my $p = process_processing($processing{$classes[0]});
    if ($p) {
      print OUT ".SH \"PROCESSING TYPE\"\n";
      print OUT nroffize($p), "\n";
    }
  }

  if ($x{'io'}) {
    print OUT ".SH \"INPUTS AND OUTPUTS\"\n";
    print OUT nroffize($x{'io'});
  }

  if ($x{'d'}) {
    print OUT ".SH \"DESCRIPTION\"\n";
    print OUT nroffize($x{'d'}, \@srelated, \%srelated_source);
  }

  if ($x{'n'}) {
    print OUT ".SH \"NOTES\"\n";
    print OUT nroffize($x{'n'}, \@srelated, \%srelated_source);
  }

  if ($x{'e'}) {
    print OUT ".SH \"EXAMPLES\"\n";
    print OUT nroffize($x{'e'}, \@srelated, \%srelated_source);
  }

  if ($x{'h'} && @{$x{'h'}}) {
    print OUT ".SH \"HANDLERS\"\n";
    print OUT "The ", $classes[0], " element installs the following additional handlers.\n";
    foreach $i (@{$x{'h'}}) {
      if ($i =~ /^(\S+)\s*(\S*)\n(.*)$/s) {
	print OUT ".TP 5\n.BR ", $1;
	print OUT " \" (", $2, ")\"" if $2;
	print OUT "\n.RS\n", nroffize($3), ".RE\n.Sp\n";
      }
    }
  }

  if (@related) {
    print OUT ".SH \"SEE ALSO\"\n";
    my($last) = pop @related;
    print OUT map(".M $_ " . $related_source{$_} . " ,\n", @related);
    print OUT ".M $last ", $related_source{$last}, "\n";
  }

  # close output file & make links if appropriate
  if ($directory) {
    close OUT;
    for ($i = 1; $i < @outfiles; $i++) {
      my($outname) = "$directory/$outfiles[$i].$outsections[$i]";
      unlink($outname);
      if (link $main_outname, $outname) {
	push @all_outfiles, $outfiles[$i];
	$all_outsections{$outfiles[$i]} = $outsections[$i];
      } else {
	print STDERR "$outname: $!\n";
      }
    }
  }
}

sub process_file ($) {
  my($filename) = @_;
  $filename =~ s/\.cc$/\.hh/;
  if (!open(IN, $filename)) {
    print STDERR "$filename: $!\n";
    return;
  }
  my $text = <IN>;
  close IN;

  foreach $_ (split(m{^class}m, $text)) {
    my($cxx_class) = (/^\s*(\w*)/);
    if (/class_name.*return\s*\"([^\"]+)\"/) {
      $class_name{$cxx_class} = $1;
      $cxx_class = $1;
    }
    if (/processing.*return\s+(.*?);/) {
      $processing{$cxx_class} = $1;
    }
  }

  foreach $_ (split(m{(/\*.*?\*/)}s, $text)) {
    if (/^\/\*/ && /^[\/*\s]+=/) {
      s/^\/\*\s*//g;
      s/\s*\*\/$//g;
      s/^[ \t]*\*[ \t]*//gm;
      process_comment($_, $filename);
    }
  }
}

# main program: parse options
sub read_files_from ($) {
  my($fn) = @_;
  if (open(IN, ($fn eq '-' ? "<&STDIN" : $fn))) {
    my(@a, @b, $t);
    $t = <IN>;
    close IN;
    @a = split(/\s+/, $t);
    foreach $t (@a) {
      next if $t eq '';
      if ($t =~ /[*?\[]/) {
	push @b, glob($t);
      } else {
	push @b, $t;
      }
    }
    @b;
  } else {
    print STDERR "$fn: $!\n";
    ();
  }
}

undef $/;
my(@files, $fn, $elementlist);
while (@ARGV) {
  $_ = shift @ARGV;
  if (/^-d$/ || /^--directory$/) {
    die "not enough arguments" if !@ARGV;
    $directory = shift @ARGV;
  } elsif (/^--directory=(.*)$/) {
    $directory = $1;
  } elsif (/^-f$/ || /^--files$/) {
    die "not enough arguments" if !@ARGV;
    push @files, read_files_from(shift @ARGV);
  } elsif (/^--files=(.*)$/) {
    push @files, read_files_from($1);
  } elsif (/^-l$/ || /^--list$/) {
    $elementlist = 1;
  } elsif (/^-./) {
    die "unknown option `$_'\n";
  } elsif (/^-$/) {
    push @files, "-";
  } else {
    push @files, glob($_);
  }
}
push @files, "-" if !@files;

umask(022);
open(OUT, ">&STDOUT") if !$directory;
foreach $fn (@files) {
  process_file($fn);
}
close OUT if !$directory;

sub make_elementlist () {
  if ($directory) {
    if (!open(OUT, ">$directory/elements.$section")) {
      print STDERR "$directory/elements.$section: $!\n";
      return;
    }
  }
  print OUT <<"EOD;";
.\\" -*- mode: nroff -*-
.\\" Generated by \`element2man.pl'
$prologue
.TH "ELEMENTS" $section "$today" "Click"
.SH "NAME"
elements \- documented Click element classes
.SH "DESCRIPTION"
This page lists all Click element classes that have manual page documentation.
.SH "SEE ALSO"
.nh
EOD;
  @all_outfiles = sort @all_outfiles;
  my($last) = pop @all_outfiles;
  print OUT map(".M $_ $all_outsections{$_} ,\n", @all_outfiles);
  print OUT ".M $last $all_outsections{$last}\n.hy\n";
  close OUT if $directory;
}
  
if ($elementlist && @all_outfiles) {
  make_elementlist();
}
