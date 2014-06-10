use strict;
use warnings;
use Test::More;
use Data::Validator::Recursive;

my $rule = Data::Validator::Recursive->new(
    foo => 'Str',
    bar => { isa => 'Int', optional => 1 },
    baz => {
        isa  => 'ArrayRef',
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
        baz => [
            {
                hoge => 'xxx',
                fuga => 123,
            },
        ],
    };
    my $params = $rule->validate($input);

    is_deeply $params, $input;
    ok !$rule->has_error;
    ok !$rule->error;
    ok !$rule->errors;
    ok !$rule->clear_errors;
};

subtest 'invalid data as array' => sub {
    my $input = {
        foo => 'xxx',
        bar => 123,
        baz => {},
    };
    ok! $rule->validate($input);

    ok $rule->has_error;
    is_deeply $rule->error, {
        name    => 'baz',
        type    => 'InvalidValue',
        message => q{'baz' is InvalidValue},
    };

    is_deeply $rule->errors, [
        {
            name    => 'baz',
            type    => 'InvalidValue',
            message => q{'baz' is InvalidValue},
        },
    ];
    is_deeply $rule->errors, $rule->clear_errors;
    ok !$rule->has_error;
};

subtest 'invalid data at the first of array' => sub {
    my $input = {
        foo => 'xxx',
        bar => 123,
        baz => [
            {
                fuga => 'piyo',
            },
            {
                hoge => 'xxx',
                fuga => 1,
            },
        ],
    };
    ok! $rule->validate($input);

    ok $rule->has_error;
    is_deeply $rule->error, {
        name    => 'baz[0].fuga',
        type    => 'InvalidValue',
        message => q{'baz[0].fuga' is InvalidValue},
    };

    is_deeply $rule->errors, [
        {
            name    => 'baz[0].fuga',
            type    => 'InvalidValue',
            message => q{'baz[0].fuga' is InvalidValue},
        },
        {
            name    => 'baz[0].hoge',
            type    => 'MissingParameter',
            message => q{'baz[0].hoge' is MissingParameter},
        },
    ];
    is_deeply $rule->errors, $rule->clear_errors;
    ok !$rule->has_error;
};

subtest 'invalid data at the second of array' => sub {
    my $input = {
        foo => 'xxx',
        bar => 123,
        baz => [
            {
                hoge => 'xxx',
                fuga => 1,
            },
            {
                fuga => 'piyo',
            },
            {
                hoge => 'xxx',
                fuga => 2,
            },
            {
                fuga => 'piyo',
            },
        ],
    };
    ok! $rule->validate($input);

    ok $rule->has_error;
    is_deeply $rule->error, {
        name    => 'baz[1].fuga',
        type    => 'InvalidValue',
        message => q{'baz[1].fuga' is InvalidValue},
    };

    is_deeply $rule->errors, [
        {
            name    => 'baz[1].fuga',
            type    => 'InvalidValue',
            message => q{'baz[1].fuga' is InvalidValue},
        },
        {
            name    => 'baz[1].hoge',
            type    => 'MissingParameter',
            message => q{'baz[1].hoge' is MissingParameter},
        },
    ];
    is_deeply $rule->errors, $rule->clear_errors;
    ok !$rule->has_error;
};

subtest 'nested array' => sub {
    my $rule = Data::Validator::Recursive->new(
        foo => 'Str',
        bar => { isa => 'Int', default => 1 },
        baz => {
            isa  => 'ArrayRef',
            rule => [
                piyo => {
                    isa => 'ArrayRef',
                    rule => [
                        hoge => { isa => 'Str', default => 'yyy' },
                        fuga => 'Int',
                    ],
                },
            ],
        },
    );

    my $input = {
        foo => 'xxx',
        baz => [
            {
                piyo => [ 
                    {
                        fuga => 123,
                    },
                ],
            },
        ],
    };

    my $params = $rule->validate($input);

    ok $params;
    is_deeply $params, {
        foo => 'xxx',
        bar => 1,
        baz => [
            {
                piyo => [
                    {
                        hoge => 'yyy',
                        fuga => 123,
                    },
                ],
            }
        ],
    } or note explain $params;

    ok !$rule->has_error;
    ok !$rule->error;
    ok !$rule->errors;
    ok !$rule->clear_errors;
};

subtest 'conflicts' => sub {
    my $input = {
        foo => 'xxx',
        bar => 123,
        baz => [
            {
                hoge => 'yyy',
                fuga => 456,
                piyo => [qw/a b c/],
            },
        ],
    };

    ok! $rule->validate($input);
    is_deeply $rule->error, {
        type     => 'ExclusiveParameter',
        name     => 'baz[0].hoge',
        message  => q{'baz[0].hoge' and 'baz[0].piyo' is ExclusiveParameter},
        conflict => 'baz[0].piyo',
    };
    is_deeply $rule->errors, [
        {
            type     => 'ExclusiveParameter',
            name     => 'baz[0].hoge',
            message  => q{'baz[0].hoge' and 'baz[0].piyo' is ExclusiveParameter},
            conflict => 'baz[0].piyo',
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
            isa  => 'ArrayRef[HashRef]',
            rule => [
                hoge => 'Str',
                fuga => 'Int',
            ],
        },
    );

    my $input = {
        foo => 'xxx',
        baz => [
            {
                hoge => 'yyy',
                fuga => 456,
            },
        ],
    };

    my $params = $rule->validate($input);

    ok $params;

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
            isa  => 'ArrayRef[HashRef]',
            rule => [
                hoge => { isa => 'Str', default => 'yyy' },
                fuga => 'Int',
            ],
        },
    );

    my $input = {
        foo => 'xxx',
        baz => [
            {
                fuga => 123,
            },
        ],
    };

    my $params = $rule->validate($input);

    is_deeply $params, {
        foo => 'xxx',
        bar => 1,
        baz => [
            {
                hoge => 'yyy',
                fuga => 123,
            },
        ],
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
            isa  => 'ArrayRef[HashRef]',
            with => 'AllowExtra',
            rule => [
                hoge => { isa => 'Str', default => 'yyy' },
                fuga => 'Int',
            ],
        },
    );
    $rule->with('AllowExtra');

    note ref $rule;

    my $input = {
        foo => 'xxx',
        baz => [
            {
                fuga => 123,
                extra_param_in_baz => 1,
            },
        ],
        extra_param => 1,
    };

    my ($params) = $rule->validate($input);

    is_deeply $params, {
        foo => 'xxx',
        bar => 1,
        baz => [
            {
                hoge => 'yyy',
                fuga => 123,
                extra_param_in_baz => 1,
            },
        ],
        extra_param => 1,
    } or note explain $params;

    note ref $rule;

    ok !$rule->has_error;
    ok !$rule->error;
    ok !$rule->errors;
    ok !$rule->clear_errors;
};

done_testing;
