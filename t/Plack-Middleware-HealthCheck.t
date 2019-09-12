use utf8;
use strict;
use warnings;
use open qw(:std :encoding(UTF-8));    # undeclared streams in UTF-8
use charnames qw( :full );

use Test::Exception;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use JSON;
use File::Temp qw();

use HealthCheck;

use Plack::Middleware::HealthCheck;

# https://metacpan.org/source/ZEFRAM/Carp-1.25/Changes#L9
my $nl = Carp->VERSION >= 1.25 ? ".\n" : "\n";

my $rx = "\N{PRESCRIPTION TAKE}";
my @unicode_paths = $rx ? ("/$rx") : ();

my $psgi_app
    = sub { [ 200, [ 'Content-Type' => 'text/plain' ], ["Hello World"] ]; };

ok( Plack::Middleware::HealthCheck->new( health_check => HealthCheck->new )
        ->health_check_paths,
    "health_check_paths with explicit health_check"
);

throws_ok { Plack::Middleware::HealthCheck->new }
    qr/health_check parameter required/,
    "Requires health_check parameter";

{
    local $SIG{__WARN__} = sub { };    # odd number of elements
    throws_ok { Plack::Middleware::HealthCheck->new('health_check') }
        qr/health_check parameter required/,
        "Undef health_check not accepted";
}

throws_ok { Plack::Middleware::HealthCheck->new(
    health_check => bless {}, 'Not::A::HealthCheck' ) }
    qr/health_check doesn't seem like a HealthCheck/,
    "Requires health_check parameter that can(check)";


{note "should_serve_health_check from default paths";
    my @non_health_check_paths = (
        '/health', '/health_check',
        '/healthZ', '/HEALTHZ',
        '/healthz/',
        @unicode_paths,
    );

    my $mw = Plack::Middleware::HealthCheck->new( {
        health_check => HealthCheck->new } );

    is_deeply $mw->health_check_paths, [ '/healthz' ],
        "With a HealthCheck object, have a default path";

    foreach my $path ( @{ $mw->health_check_paths } ) {
        ok $mw->should_serve_health_check( { PATH_INFO => $path } ),
            "[$path] Should serve health_check";
    }

    foreach my $path (@non_health_check_paths) {
        ok !$mw->should_serve_health_check( { PATH_INFO => $path } ),
            "[$path] Should NOT serve health_check";
    }
}

{ note "should_serve_health_check from custom paths";
    my @custom_paths = ( '/foo', '/bar', @unicode_paths );

    my $mw = Plack::Middleware::HealthCheck->new(
        health_check => HealthCheck->new,
        health_check_paths => [@custom_paths] );

    is_deeply $mw->health_check_paths, [ @custom_paths ],
        "Have custom paths, even without a health_check object";

    foreach my $path ( @{ $mw->health_check_paths } ) {
        ok $mw->should_serve_health_check( { PATH_INFO => $path } ),
            "[$path] Should serve health_check";
    }

    foreach my $path ( '/healthz', '/_healthcheck' ) {
        ok !$mw->should_serve_health_check( { PATH_INFO => $path } ),
            "[$path] Should NOT serve health_check";
    }
}

{ note "should_serve_health_check custom paths not overriden by health_check";
    my $mw = Plack::Middleware::HealthCheck->new(
        health_check       => HealthCheck->new,
        health_check_paths => [@unicode_paths] );

    is_deeply $mw->health_check_paths, [@unicode_paths],
        "Have custom paths, even with a health_check object";
}

{ note "Pass tags from query string to health_check->check";
    my %args;
    my $args_ok = sub {
        my ($expect, @message) = @_;

        local $Test::Builder::Level = $Test::Builder::Level + 1;

        delete $args{env}; # Don't try to test env, we always include it
        is_deeply \%args, $expect, @message;

        %args = ();
    };

    no warnings 'once';
    local *My::HealthCheck::check
        = sub { %args = @_[1..$#_]; return { status => 'OK' } };
    use warnings 'once';
    my $hc = bless {}, 'My::HealthCheck';

    test_psgi( Plack::Middleware::HealthCheck->wrap($psgi_app,
            health_check_paths => ['/'],
            health_check => $hc ) => sub {
        my ($cb) = @_;

        $cb->( GET '/' );
        $args_ok->( {}, "No query_string" );

        $cb->( GET '/?foo=bar&qux=quux' );
        $args_ok->( {}, "No tags" );

        $cb->( GET '/?foo=bar&tags=foo&qux=quux' );
        $args_ok->( { tags => [qw( foo )] }, "Single tag" );

        $cb->( GET '/?tags=foo&tags=bar&qux=quux' );
        $args_ok->( { tags => [qw( foo bar )] }, "Multiple tags" );

        $cb->( GET '/?foo=bar&tags=&qux=quux' );
        $args_ok->( { tags => [''] }, "Blank tag" );

        $cb->( GET '/?foo=bar&qux=quux&tags=0' );
        $args_ok->( { tags => ['0'] }, "Falsy Zero tag" );

        $cb->( POST '/', [ foo => 'bar', tags => 'foo' ] );
        $args_ok->( {}, "No query_string on POST, body params ignored" );

        $cb->( POST '/?tags=foo', [ foo => 'bar', tags => 'bar' ] );
        $args_ok->(
            { tags => ['foo'] },
            "POST query string params used, body params ignored"
        );
    } );

    test_psgi( Plack::Middleware::HealthCheck->wrap($psgi_app,
            health_check_paths => ['/'],
            allowed_params => 'weather',
            health_check   => $hc ) => sub {
        my ($cb) = @_;

        $cb->( GET '/?weather=sunshine&tags=get_weather' );
        $args_ok->(
            { tags => ['get_weather'], weather => ['sunshine'] },
            "GET get_weather tag, sunshine weather (scalar param)"
        );

        $cb->( POST '/?weather=sunshine&tags=get_weather' );
        $args_ok->(
            { tags => ['get_weather'], weather => ['sunshine'] },
            "POST get_weather tag, sunshine weather (scalar param)"
        );
    } );

    test_psgi( Plack::Middleware::HealthCheck->wrap($psgi_app,
            health_check_paths => ['/'],
            allowed_params => [ 'weather' ],
            health_check   => $hc ) => sub {
        my ($cb) = @_;

        $cb->( POST '/?weather=sunshine&weather=rain&tags=get_weather',
            [ tags => 'fake', weather => 'ignored', some_other => 'nope', ]
        );
        $args_ok->(
            { tags => ['get_weather'], weather => ['sunshine', 'rain'] },
            "get_weather tag, sunshine counties (array param)"
        );

        $cb->( POST '/?weather=sunshine&tags=get_weather&some_other=fail',
            [ tags => 'fake', weather => 'ignored', some_other => 'nope', ]
        );
        $args_ok->(
            { tags => ['get_weather'], weather => ['sunshine'] },
            "get_weather doesn't pass some_other param"
        );

        $cb->( POST '/?weather=', [ tags => 'ignored' ] );
        $args_ok->(
            { weather => [''] },
            "get_weather with empty weather list"
        );

        $cb->( POST '/' );
        $args_ok->( {}, "get_weather without weather specified" );
    } );

    {
        local $@;
        eval { local $SIG{__DIE__};
            Plack::Middleware::HealthCheck->new(
                allowed_params => [ 'env' ],
                health_check   => $hc
            );
        };
        my $at = sprintf( "at %s line %d", __FILE__, __LINE__ - 5 );
        is $@,
            "Cannot overload \%env params $at$nl",
            "Overloading \%env prohibited";
    }

    {
        local $@;
        eval { local $SIG{__DIE__};
            Plack::Middleware::HealthCheck->new(
                allowed_params => { 'weather' => 'foo' },
                health_check   => $hc
            );
        };
        my $at = sprintf( "at %s line %d", __FILE__, __LINE__ - 5 );
        is $@,
            "HealthCheck allowed_params must be an arrayref of strings"
            . "; found HASH $at$nl",
            "Constructor requires allowed_params be arrayref";
    }

    {
        local $@;
        eval { local $SIG{__DIE__};
            Plack::Middleware::HealthCheck->new(
                allowed_params => [ {} ],
                health_check   => $hc
            );
        };
        my $at = sprintf( "at %s line %d", __FILE__, __LINE__ - 5 );
        is $@,
            "HealthCheck allowed_params must be an arrayref of strings"
            . "; found HASH value $at$nl",
            "Constructor requires allowed_params be arrayref of strings";
    }
}

{ note "health_check warnings sent to psgi.errors";
    my $catcher = My::Middleware::ErrorCatcher->new;
    my $wrapped = $catcher->wrap(
        Plack::Middleware::HealthCheck->wrap( $psgi_app,
            no_default_checks => 1,
            health_check => HealthCheck->new( checks => [
                sub { warn "Oh Noes!"; { status => "WARNING" } },
            ] ),
        ) );
    my $at = sprintf( "at %s line %d.", __FILE__, __LINE__ - 3 );

    my @errors;
    test_psgi $wrapped => sub {
        my ($cb) = @_;
        my $res = $cb->( GET "/healthz" );
        push @errors, "Oh Noes! $at\n";

        is $res->code, 503, "Failed health check";
        is $res->content_type, "application/json",
            "With expected charset";
        is $res->content, qq({"status":"WARNING"}),
            "Got the result we expected";
    };

    is_deeply $catcher->errors, \@errors, "Got expected errors";
}

{ note "health_check_response";
    my $mw = Plack::Middleware::HealthCheck->new(
        health_check => HealthCheck->new );
    my @content_type = ( content_type => 'application/json; charset=utf-8' );

    is_deeply $mw->health_check_response,
        [ 503, [@content_type], [qq({})] ],
        "Error without a result hashref";

    is_deeply $mw->health_check_response( { status => 'OK' } ),
        [ 200, [@content_type], [qq({"status":"OK"}) ] ],
        "OK with an OK result";

    foreach my $status (qw( UNKNOWN WARNING CRITICAL other )) {
        is_deeply $mw->health_check_response( { status => $status } ), [
            503, [@content_type],
            [qq({"status":"$status"}) ]
        ], "Error with $status status";
    }
}

{ note "health_check_response with \$req can be pretty";
    my $mw = Plack::Middleware::HealthCheck->new(
        health_check => HealthCheck->new );
    my @content_type = ( content_type => 'application/json; charset=utf-8' );

    my $req = Plack::Request->new({});

    is_deeply $mw->health_check_response( { status => 'OK' }, $req ),
        [ 200, [@content_type], [qq({"status":"OK"}) ] ],
        "JSON encoded result is compact";

    # Make sure it just needs to exist, not be set
    $req->query_parameters->set( pretty => undef );

    # Hopefully JSON keeps making this pretty in the same way
    is_deeply $mw->health_check_response( { status => 'OK' }, $req ),
        [ 200, [@content_type], [qq({\n   "status" : "OK"\n}\n) ] ],
        "JSON encoded result with ?pretty is pretty";
}

done_testing;

package My::Middleware::ErrorCatcher;
use parent 'Plack::Middleware';

use Plack::Util::Accessor qw(errors);

sub new { shift->SUPER::new( errors => [], @_ ) }

sub call {
    my ($self, $env) = @_;

    open my $err_fh, '>', \my $errors or die $!;
    $env->{'psgi.errors'} = $err_fh;

    $self->response_cb( $self->app->($env), sub {
        push @{ $self->errors }, $errors;
    } );
}

1;
