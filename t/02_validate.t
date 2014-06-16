use strict;
use warnings;
use Test::More;
use Data::Validator::Recursive;

my $rule = Data::Validator::Recursive->new(
    foo => 'Str',
    bar => { isa => 'Int', optional => 1 },
    baz => {
        isa  => 'HashRef',
        rule => [
            hoge => 'Str',
            fuga => 'Int',
            piyo => {
                isa      => 'ArrayRef',
                xor      => [qw/hoge/],
                optional => 1,
            },
        ],
    },
);

subtest 'valid data' => sub {
    my $input = {
        foo => 'xxx',
        bar => 123,
        baz => {
            hoge => 'xxx',
            fuga => 123,
        },
    };
    my $params = $rule->validate($input);

    is_deeply $params, $input;
    ok !$rule->has_error;
    ok !$rule->error;
    ok !$rule->errors;
    ok !$rule->clear_errors;
};

subtest 'invalid data' => sub {
    my $input = {
        foo => 'xxx',
        bar => 123,
        baz => {
            fuga => 'piyo',
        },
    };
    ok! $rule->validate($input);

    ok $rule->has_error;
    is_deeply $rule->error, {
        name    => 'baz.fuga',
        type    => 'InvalidValue',
        message => q{'baz.fuga' is InvalidValue},
    };

    is_deeply $rule->errors, [
        {
            name    => 'baz.fuga',
            type    => 'InvalidValue',
            message => q{'baz.fuga' is InvalidValue},
        },
        {
            name    => 'baz.hoge',
            type    => 'MissingParameter',
            message => q{'baz.hoge' is MissingParameter},
        },
    ];
    is_deeply $rule->errors, $rule->clear_errors;
    ok !$rule->has_error;
};

subtest 'conflicts' => sub {
    my $input = {
        foo => 'xxx',
        bar => 123,
        baz => {
            hoge => 'yyy',
            fuga => 456,
            piyo => [qw/a b c/],
        },
    };

    ok! $rule->validate($input);
    is_deeply $rule->error, {
        type     => 'ExclusiveParameter',
        name     => 'baz.hoge',
        message  => q{'baz.hoge' and 'baz.piyo' is ExclusiveParameter},
        conflict => 'baz.piyo',
    };
    is_deeply $rule->errors, [
        {
            type     => 'ExclusiveParameter',
            name     => 'baz.hoge',
            message  => q{'baz.hoge' and 'baz.piyo' is ExclusiveParameter},
            conflict => 'baz.piyo',
        },
    ];
    is_deeply $rule->errors, $rule->clear_errors;
    ok !$rule->has_error;
};

subtest 'with default option' => sub {
    my $rule = Data::Validator::Recursive->new(
        foo => 'Str',
        bar => { isa => 'Int', default => 1 },
        baz => {
            isa  => 'HashRef',
            rule => [
                hoge => 'Str',
                fuga => 'Int',
            ],
        },
    );

    my $input = {
        foo => 'xxx',
        baz => {
            hoge => 'xxx',
            fuga => 123,
        },
    };

    my $params = $rule->validate($input);

    is_deeply $params, { %$params, bar => 1 }
        or note explain $params;

    ok !$rule->has_error;
    ok !$rule->error;
    ok !$rule->errors;
    ok !$rule->clear_errors;

};

subtest 'default option with nested' => sub {
    my $rule = Data::Validator::Recursive->new(
        foo => 'Str',
        bar => { isa => 'Int', default => 1 },
        baz => {
            isa  => 'HashRef',
            rule => [
                hoge => { isa => 'Str', default => 'yyy' },
                fuga => 'Int',
            ],
        },
    );

    my $input = {
        foo => 'xxx',
        baz => {
            fuga => 123,
        },
    };

    my $params = $rule->validate($input);

    is_deeply $params, {
        foo => 'xxx',
        bar => 1,
        baz => {
            hoge => 'yyy',
            fuga => 123,
        },
    } or note explain $params;

    ok !$rule->has_error;
    ok !$rule->error;
    ok !$rule->errors;
    ok !$rule->clear_errors;
};

subtest 'with AllowExtra' => sub {
    my $rule = Data::Validator::Recursive->new(
        foo => 'Str',
        bar => { isa => 'Int', default => 1 },
        baz => {
            isa  => 'HashRef',
            with => 'AllowExtra',
            rule => [
                hoge => { isa => 'Str', default => 'yyy' },
                fuga => 'Int',
            ],
        },
    )->with('AllowExtra');

    note ref $rule;

    my $input = {
        foo => 'xxx',
        baz => {
            fuga => 123,
            extra_param_in_baz => 1,
        },
        extra_param => 1,
    };

    my ($params) = $rule->validate($input);

    is_deeply $params, {
        foo => 'xxx',
        bar => 1,
        baz => {
            hoge => 'yyy',
            fuga => 123,
            extra_param_in_baz => 1,
        },
        extra_param => 1,
    } or note explain $params;

    note ref $rule;

    ok !$rule->has_error;
    ok !$rule->error;
    ok !$rule->errors;
    ok !$rule->clear_errors;
};

done_testing;
