package Regexp::Pattern::Example;

# DATE
# VERSION

use 5.010001;

# BEGIN_BLOCK: def

our %RE = (
    # the minimum spec
    re1 => { pat => qr/\d{3}-\d{3}/ },

    # more complete spec
    re2 => {
        summary => 'This is regexp for blah', # plaintext
        description => <<'_',

A longer description in *Markdown* format.

_
        pat => qr/\d{3}-\d{3}(?:-\d{5})?/,
        tags => ['A','B'],
        examples => [
            # examples can be tested using 'test-regexp-pattern' script
            # (distributed in Test-Regexp-Pattern distribution). examples can
            # also be rendered in your POD using
            # Pod::Weaver::Plugin::Regexp::Pattern.
            {
                str => '123-456',
                matches => 1,
            },
            {
                summary => 'Another example that matches',
                str => '123-456-78901',
                matches => 1,
            },
            {
                summary => 'An example that does not match',
                str => '123456',
                matches => 0,
            },
            {
                summary => 'An example that does not get tested',
                str => '123456',
            },
            {
                summary => 'Another example that does not get tested nor rendered to POD',
                str => '234567',
                matches => 0,
                test => 0,
                doc => 0,
            },
        ],
    },

    # dynamic (regexp generator)
    re3 => {
        summary => 'This is a regexp for blah blah',
        description => <<'_',

...

_
        gen => sub {
            my %args = @_;
            my $variant = $args{variant} || 'A';
            if ($variant eq 'A') {
                return qr/\d{3}-\d{3}/;
            } else { # B
                return qr/\d{3}-\d{2}-\d{5}/;
            }
        },
        gen_args => {
            variant => {
                summary => 'Choose variant',
                schema => ['str*', in=>['A','B']],
                default => 'A',
                req => 1,
            },
        },
        tags => ['B','C'],
        examples => [
            {
                summary => 'An example that matches',
                gen_args => {variant=>'A'},
                str => '123-456',
                matches => 1,
            },
            {
                summary => "An example that doesn't match",
                gen_args => {variant=>'B'},
                str => '123-456',
                matches => 0,
            },
        ],
    },

    re4 => {
        summary => 'This is a regexp that does capturing',
        # it is recommended that your pattern does not capture, unless
        # necessary. capturing pattern should tag with 'capturing' to let
        # users/tools know.
        tags => ['capturing'],
        pat => qr/(\d{3})-(\d{3})/,
        examples => [
            {str=>'123-456', matches=>[123, 456]},
            {str=>'foo-bar', matches=>[]},
        ],
    },

    re5 => {
        summary => 'This is another regexp that is anchored and does (named) capturing',
        # it is recommended that your pattern is not anchored for more
        # reusability, unless necessary. anchored pattern should tag with
        # 'anchored' to let users/tools know.
        tags => ['capturing', 'anchored'],
        pat => qr/^(?<cap1>\d{3})-(?<cap2>\d{3})/,
        examples => [
            {str=>'123-456', matches=>{cap1=>123, cap2=>456}},
            {str=>'something 123-456', matches=>{}},
        ],
    },
);

# END_BLOCK: def

1;
# ABSTRACT: An example Regexp::Pattern::* module
