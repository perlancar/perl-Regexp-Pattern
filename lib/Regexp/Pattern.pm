package Regexp::Pattern;

# AUTHORITY
# DATE
# DIST
# VERSION

use strict 'subs', 'vars';
#use warnings;

my %loaded_module_info; # key = name (without Regexp::Pattern:: prefix), value = {engine=>...}
sub _load_rp_module {
    my ($rp_module, %opts) = @_;

    my $module = "Regexp::Pattern::$rp_module";
    (my $module_pm = "$module.pm") =~ s!::!/!g;

    my $engine = $opts{engine} || "(perl)";

  CHECK_ALREADY_LOADED:
    {
        if ($loaded_module_info{$rp_module}) {
            if ($engine ne $loaded_module_info{$rp_module}{engine}) {
                die "Module $module was loaded by us with ".($engine eq '(perl)' ? "default regexp engine" : "re::engine::$engine").
                    ", while we are now requesting to load it with ".($engine eq '(perl)' ? "default regexp engine" : "re::engine::$engine");
            }
            return;
        } elsif (exists $INC{$module_pm}) {
            if ($engine ne '(perl)') {
                die "Module $module was loaded by some other code with (presumably) default regexp engine".
                    ", while we are now requesting to load it with re::engine::$engine";
            }
            return;
        }
    }

    require Require::Hook::More;
    local @INC = (Require::Hook::More->new(
        #debug => 1,
        prepend_code => $engine eq '(perl)' ? '' : "use re::engine::$engine; ",
    ), @INC);
    require $module_pm;

    $loaded_module_info{$rp_module} = {
        engine => $engine,
    };
}

sub re {
    my $name = shift;
    my %args = ref($_[0]) eq 'HASH' ? %{$_[0]} : @_;

    my ($rp_module, $patname) = $name =~ /(.+)::(.+)/
        or die "Invalid pattern name '$name', should be 'MODNAME::PATNAME'";

    # special args, but will also be passed as gen_args
    my $opt_anchor = $args{-anchor};
    my $opt_engine = $args{-engine};

    my $module = "Regexp::Pattern::$rp_module";
    _load_rp_module($rp_module, engine=>$opt_engine);

    my $var = \%{"$module\::RE"};

    exists($var->{$patname})
        or die "No regexp pattern named '$patname' in package '$module'";

    my $pat;
    if ($var->{$patname}{pat}) {
        $pat = $var->{$patname}{pat};
    } elsif ($var->{$patname}{gen}) {
        $pat = $var->{$patname}{gen}->(%args);
    } else {
        die "Bug in module '$module': pattern '$patname': no pat/gen declared";
    }

    if ($opt_anchor) {
        $pat = qr/\A(?:$pat)\z/;
    }

    return $pat;
}

sub import {
    my $package = shift;

    my $caller = caller();

    my @args = @_;
    @args = ('re') unless @args;

    while (@args) {
        my $arg = shift @args;
        my ($rp_module, $name0, $as, $prefix, $suffix,
            $has_tag, $lacks_tag, $gen_args);
        if ($arg eq 're') {
            *{"$caller\::re"} = \&re;
            next;
        } elsif ($arg =~ /\A(\w+(?:::\w+)*)::(\w+|\*)\z/) {
            ($rp_module, $name0) = ($1, $2);
            ($as, $prefix, $suffix, $has_tag, $lacks_tag) =
                (undef, undef, undef, undef, undef);
            $gen_args = {};
            if (@args && ref $args[0] eq 'HASH') {
                $gen_args = shift @args;
                next;
            }
            while (@args >= 2 && $args[0] =~ /\A-?\w+\z/) {
                my ($k, $v) = splice @args, 0, 2;
                if ($k eq '-as') {
                    die "Cannot use -as on a wildcard import '$arg'"
                        if $name0 eq '*';
                    die "Please use a simple identifier for value of -as"
                        unless $v =~ /\A\w+\z/;
                    $as = $v;
                } elsif ($k eq '-engine') {
                    $gen_args->{-engine} = $v;
                } elsif ($k eq '-anchor') {
                    $gen_args->{-engine} = $v;
                } elsif ($k eq '-prefix') {
                    $prefix = $v;
                } elsif ($k eq '-suffix') {
                    $suffix = $v;
                } elsif ($k eq '-has_tag') {
                    $has_tag = $v;
                } elsif ($k eq '-lacks_tag') {
                    $lacks_tag = $v;
                } elsif ($k !~ /\A-/) {
                    $gen_args->{$k} = $v;
                } else {
                    die "Unknown import option '$k'";
                }
            }
        } else {
            die "Invalid import '$arg', either specify 're' or a qualified ".
                "pattern name e.g. 'Foo::bar', which can be followed by ".
                "name-value pairs";
        }

        *{"$caller\::RE"} = \%{"$caller\::RE"};

        my @names;
        if ($name0 eq '*') {
            my $module = "Regexp::Pattern::$rp_module";
            _load_rp_module($rp_module, engine=>$gen_args->{-engine});
            my $var = \%{"$module\::RE"};
            for my $n (sort keys %$var) {
                my $tags = $var->{$n}{tags} || [];
                if (defined $has_tag) {
                    next unless grep { $_ eq $has_tag } @$tags;
                }
                if (defined $lacks_tag) {
                    next if grep { $_ eq $lacks_tag } @$tags;
                }
                push @names, $n;
            }
            unless (@names) {
                warn "No patterns imported in wildcard import '$module\::*'";
            }
        } else {
            @names = ($name0);
        }
        for my $n (@names) {
            my $name = defined($as) ? $as :
                (defined $prefix ? $prefix : "") . $n .
                (defined $suffix ? $suffix : "");
            if (exists ${"$caller\::RE"}{$name}) {
                warn "Overwriting pattern '$name' by importing '$rp_module\::$n'";
            }
            ${"$caller\::RE"}{$name} = re("$rp_module\::$n", $gen_args);
        }
    }
}

1;
# ABSTRACT: Convention/framework for modules that contain collection of regexes

=head1 SYNOPSIS

Subroutine interface:

 use Regexp::Pattern; # exports re()

 my $re = re('YouTube::video_id');
 say "ID does not look like a YouTube video ID" unless $id =~ /\A$re\z/;

 # a dynamic pattern (generated on-demand) with generator arguments
 my $re2 = re('Example::re3', {variant=>"B"});

Hash interface (a la L<Regexp::Common> but simpler with regular/non-magical hash
that is only 1-level deep):

 use Regexp::Pattern 'YouTube::video_id';
 say "ID does not look like a YouTube video ID"
     unless $id =~ /\A$RE{video_id}\z/;

 # more complex example

 use Regexp::Pattern (
     're',                                # we still want the re() function
     'Foo::bar' => (-as => 'qux'),        # the pattern will be in your $RE{qux}
     'YouTube::*',                        # wildcard import
     'Example::re3' => (variant => 'B'),  # supply generator arguments
     'JSON::*' => (-prefix => 'json_'),   # add prefix
     'License::*' => (
       -has_tag    => 'family:cc',        # select by tag
       -lacks_tag  => 'type:unversioned', #   also select by lack of tag
       -suffix     => '_license',         #   also add suffix
     ),
 );


=head1 SPECIFICATION VERSION

0.2

=head1 DESCRIPTION

Regexp::Pattern is a convention for organizing reusable regexp patterns in
modules, as well as framework to provide convenience in using those patterns in
your program.

=head2 Structure of an example Regexp::Pattern::* module

 package Regexp::Pattern::Example;

# INSERT_BLOCK: lib/Regexp/Pattern/Example.pm def pod_verbatim

A Regexp::Pattern::* module must declare a package global hash variable named
C<%RE>. Hash keys are pattern names, hash values are pattern definitions in the
form of defhashes (see L<DefHash>).

Pattern name should be a simple identifier that matches this regexp: C<<
/\A[A-Za-z_][A-Za-z_0-9]*\z/ >>. The definition for the qualified pattern name
C<Foo::Bar::baz> can then be located in C<%Regexp::Pattern::Foo::Bar::RE> under
the hash key C<baz>.

Pattern definition hash should at the minimum be:

 { pat => qr/.../ }

You can add more stuffs from the defhash specification, e.g. summary,
description, tags, and so on, for example (taken from L<Regexp::Pattern::CPAN>):

 {
     summary     => 'PAUSE author ID, or PAUSE ID for short',
     pat         => qr/[A-Z][A-Z0-9]{1,8}/,
     description => <<~HERE,
     I'm not sure whether PAUSE allows digit for the first letter. For safety
     I'm assuming no.
     HERE
     examples => [
         {str=>'PERLANCAR', matches=>1},
         {str=>'BAD ID', anchor=>1, matches=>0},
     ],
 }

B<Examples>. Your regexp specification can include an C<examples> property (see
above for example). The value of the C<examples> property is an array, each of
which should be a defhash. For each example, at the minimum you should specify
C<str> (string to be matched by the regexp), C<gen_args> (hash, arguments to use
when generating dynamic regexp pattern), and C<matches> (a boolean value that
specifies whether the regexp should match the string or not, or an array/hash
that specifies the captures). You can of course specify other defhash properties
(e.g. C<summary>, C<description>, etc). Other example properties might be
introduced in the future.

If you use L<Dist::Zilla> to build your distribution, you can use the plugin
L<[Regexp::Pattern]|Dist::Zilla::Plugin::Regexp::Pattern> to test the examples
during building, and the L<Pod::Weaver> plugin
L<[-Regexp::Pattern]|Pod::Weaver::Plugin::Regexp::Pattern> to render the
examples in your POD.

=head2 Using a Regexp::Pattern::* module

=head3 Standalone

A Regexp::Pattern::* module can be used in a standalone way (i.e. no need to use
via the Regexp::Pattern framework), as it simply contains data that can be
grabbed using a normal means, e.g.:

 use Regexp::Pattern::Example;

 say "Input does not match blah"
     unless $input =~ /\A$Regexp::Pattern::Example::RE{re1}{pat}\z/;

=head3 Via Regexp::Pattern, sub interface

Regexp::Pattern (this module) also provides C<re()> function to help retrieve
the regexp pattern. See L</"re"> for more details.

=head3 Via Regexp::Pattern, hash interface

Additionally, Regexp::Pattern (since v0.2.0) lets you import regexp patterns
into your C<%RE> package hash variable, a la L<Regexp::Common> (but simpler
because the hash is just a regular hash, only 1-level deep, and not magical).

To import, you specify qualified pattern names as the import arguments:

 use Regexp::Pattern 'Q::pat1', 'Q::pat2', ...;

Each qualified pattern name can optionally be followed by a list of name-value
-pairs. A pair name can be an option name (which is dash followed by a word,
e.g. -C<-as>, C<-prefix>) or a generator argument name for dynamic pattern.

B<Wildcard import.> Instead of a qualified pattern name, you can use
'Module::SubModule::*' wildcard syntax to import all patterns from a pattern
module.

B<Importing into a different name.> You can add the import option C<-as> to
import into a different name, for example:

 use Regexp::Pattern 'YouTube::video_id' => (-as => 'yt_id');

B<Prefix and suffix.> You can also add a prefix and/or suffix to the imported
name:

 use Regexp::Pattern 'Example::*' => (-prefix => 'example_');
 use Regexp::Pattern 'Example::*' => (-suffix => '_sample');

B<Filtering.> When wildcard-importing, you can select the patterns you want
using a combination of these options: C<-has_tag> (only select patterns that
have a specified tag), C<-lacks_tag> (only select patterns that do not have a
specified tag).

B<Other options.> C<-anchor> and C<-engine> will be passed to re() in the second
hashref argument.

=head2 Recommendations for writing the regex patterns

=over

=item * Regexp pattern should be written as a C<qr//> literal

Using a string literal is less desirable. That is:

 pat => qr/foo[abc]+/,

is preferred over:

 pat => 'foo[abc]+',

=item * Regexp pattern should not be anchored (unless really necessary)

That is:

 pat => qr/foo/,

is preferred over:

 pat => qr/^foo/, # or qr/foo$/, or qr/\Afoo\z/

Adding anchors limits the reusability of the pattern. When composing pattern,
user can add anchors herself if needed.

When you define an anchored pattern, adding tag C<anchored> is recommended:

 tags => ['anchored'],

=item * Regexp pattern should not contain capture groups (unless really necessary)

Adding capture groups limits the reusability of the pattern because it can
affect the groups of the composed pattern. When composing pattern, user can add
captures herself if needed.

When you define a capturing pattern, adding tag C<capturing> is recommended:

 tags => ['capturing'],

=back


=head1 FUNCTIONS

=head2 re

Exported by default. Get a regexp pattern by name from a C<Regexp::Pattern::*>
module.

Usage:

 re($name[, \%args ]) => $re

C<$name> is I<MODULE_NAME::PATTERN_NAME> where I<MODULE_NAME> is name of a
C<Regexp::Pattern::*> module without the C<Regexp::Pattern::> prefix and
I<PATTERN_NAME> is a key to the C<%RE> package global hash in the module. A
dynamic pattern can accept arguments for its generator, and you can pass it as
hashref in the second argument of C<re()>.

B<Selecting regex engine.> You can also put C<< -engine => $name >> in C<%args>.
This will cause the Regexp::Pattern::* module to be loaded with a specific
C<re::engine::$name> module pragma. An exception will be thrown if the module
has already been loaded with a different re::engine::* pragma.

B<Anchoring.> You can also put C<< -anchor => 1 >> in C<%args>. This will
conveniently wraps the regex inside C<< qr/\A(?:...)\z/ >>.

Die when pattern by name C<$name> cannot be found (either the module cannot be
loaded or the pattern with that name is not found in the module).


=head1 FAQ

=head2 My pattern is not anchored, but what if I want to test the anchored version?

You can add C<< anchor=>1 >> or C<< gen_args=>{-anchor=>1} >> in the example,
for example:

 {
     summary     => 'PAUSE author ID, or PAUSE ID for short',
     pat         => qr/[A-Z][A-Z0-9]{1,8}/,
     description => <<~HERE,
     I'm not sure whether PAUSE allows digit for the first letter. For safety
     I'm assuming no.
     HERE
     examples => [
         {str=>'PERLANCAR', matches=>1},
         {str=>'BAD ID', anchor=>1, matches=>0, summary=>"Contains whitespace"},
         {str=>'NAMETOOLONG', gen_args=>{-anchor=>1}, matches=>0, summary=>"Too long"},
     ],
 }


=head1 SEE ALSO

L<Regexp::Common>. Regexp::Pattern is an alternative to Regexp::Common.
Regexp::Pattern offers simplicity and lower startup overhead. Instead of a magic
hash, you retrieve available regexes from normal data structure or via the
provided C<re()> function. Regexp::Pattern also provides a hash interface,
albeit the hash is not magic.

L<Regexp::Common::RegexpPattern>, a bridge module to use patterns in
C<Regexp::Pattern::*> modules via Regexp::Common.

L<Regexp::Pattern::RegexpCommon>, a bridge module to use patterns in
C<Regexp::Common::*> modules via Regexp::Pattern.

L<App::RegexpPatternUtils>

If you use L<Dist::Zilla>: L<Dist::Zilla::Plugin::Regexp::Pattern>,
L<Pod::Weaver::Plugin::Regexp::Pattern>,
L<Dist::Zilla::Plugin::AddModule::RegexpCommon::FromRegexpPattern>,
L<Dist::Zilla::Plugin::AddModule::RegexpPattern::FromRegexpCommon>.

L<Test::Regexp::Pattern> and L<test-regexp-pattern>.
