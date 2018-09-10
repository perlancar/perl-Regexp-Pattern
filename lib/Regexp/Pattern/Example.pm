package Regexp::Pattern::Example;

# DATE
# VERSION

# BEGIN_BLOCK: def

our %RE = (
    # the minimum spec
    re1 => { pat => qr/\d{3}-\d{3}/ },

    # more complete spec
    re2 => {
        summary => 'This is regexp for blah',
        description => <<'_',

A longer description.

_
        pat => qr/\d{3}-\d{3}(?:-\d{5})?/,
        tags => ['A','B'],
        examples => [
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
    },
);

# END_BLOCK: def

1;
# ABSTRACT: An example Regexp::Pattern::* module
