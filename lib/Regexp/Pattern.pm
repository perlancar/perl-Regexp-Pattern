package Regexp::Pattern;

# DATE
# VERSION

use strict 'subs', 'vars';
#use warnings;

use Exporter qw(import);
our @EXPORT = qw(re);
our @EXPORT_OK = qw(get_re_pat list_re_pats list_re_pat_modules re);

sub get_re_pat {
    my $name = shift;

    my ($mod, $patname) = $name =~ /(.+)::(.+)/
        or die "Invalid pattern name '$name', should be 'MODNAME::PATNAME'";

    $mod = "Regexp::Pattern::$mod";
    (my $mod_pm = "$mod.pm") =~ s!::!/!g;
    require $mod_pm;

    my $var = \%{"$mod\::RE"};

    exists($var->{$patname})
        or die "No regexp pattern named '$patname' in package '$mod'";

    if ($var->{$patname}{pat}) {
        return $var->{$patname}{pat};
    } elsif ($var->{$patname}{gen}) {
        return $var->{$patname}{gen}->(@_);
    } else {
        die "Bug in module '$mod': pattern '$patname': no pat/gen declared";
    }
}

sub list_re_pats {
    die "Not yet implemented";
}

sub list_re_pat_modules {
    die "Not yet implemented";
}

*re = \&get_re_pat;


1;
# ABSTRACT: Collection of regexp patterns

=head1 SYNOPSIS

 use Regexp::Pattern; # exports re()

 my $re = re('YouTube::video_id');
 say "ID does not look like a YouTube video ID" unless $id =~ /\A$re\z/;


=head1 SPECIFICATION VERSION

0.1.0

=head1 DESCRIPTION

Regexp::Pattern is a convention for organizing reusable regexp patterns in
modules.

=head2 Structure of an example Regexp::Pattern::* module

 package Regexp::Pattern::Example;

# INSERT_BLOCK: lib/Regexp/Pattern/Example.pm def pod_verbatim

A Regexp::Pattern::* module must declare a package global hash variable named
C<%RE>. Hash keys are pattern names, hash values are defhashes (see L<DefHash>).
At the minimum, it should be:

 { pat => qr/.../ },

Regexp pattern should be written as C<qr//> literal, or (less desirable) as a
string literal. Regexp should not be anchored (C<qr/^...$/>) unless necessary.
Regexp should not contain capture groups unless necessary.

=head2 Using a Regexp::Pattern::* module

A C<Regexp::Pattern::*> module can be used manually by itself, as it contains
simply data that can be grabbed using a normal means, e.g.:

 use Regexp::Pattern::Example;

 say "Input does not match blah"
     unless $input =~ /\A$Regexp::Pattern::Example::RE{re1}{pat}\z/;

C<Regexp::Pattern> (this module) also provides C<re()> function


=head1 FUNCTIONS

=head2 get_re_pat

Get a regexp pattern by name from a C<Regexp::Pattern::*> module.

Syntax:

 get_re_pat($name[, \%args ]) => $re

C<$name> is I<MODULE_NAME::PATTERN_NAME> where I<MODULE_NAME> is name of a
C<Regexp::Pattern::*> module without the C<Regexp::Pattern::> prefix and
I<PATTERN_NAME> is a key to the C<%RE> package global hash in the module.

Die when pattern by name C<$name> cannot be found (either the module cannot be
loaded or the pattern with that name is not found in the module).


=head1 SEE ALSO

L<Regexp::Common>. Regexp::Pattern is an alternative to Regexp::Common.
Regexp::Pattern offers simplicity and lower startup overhead. Instead of a magic
hash, you retrieve available regexes from normal data structure or via the
provided C<re()> function.

L<Regexp::Common::RegexpPattern>, a bridge module to use patterns in
C<Regexp::Pattern::*> modules via Regexp::Common.

L<App::RegexpPatternUtils>
