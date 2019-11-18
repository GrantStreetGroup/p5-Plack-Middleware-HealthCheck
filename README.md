# NAME

Plack::Middleware::HealthCheck - A health check endpoint for your Plack app

# VERSION

version 0.0.1

# SYNOPSIS

    $psgi_app = Plack::Middleware::HealthCheck->wrap( $psgi_app,
        health_check => HealthCheck->new(...),
    )

This automatically serves the results as JSON at `/healthz`.

You can serve the results from different ["health\_check\_paths"](#health_check_paths) than the default,
and you can specify which query parameters,
other than the always allowed `tags`,
are passed to the check with ["allowed\_params"](#allowed_params).

    $psgi_app = HealthCheck::Diagnostic::LoadAverage->wrap( $psgi_app,
        health_check       => HealthCheck->new(...),
        health_check_paths => ['/_healthcheck'],
        allowed_params     => [ 'foo', 'bar' ],
    );

# DESCRIPTION

Does a basic health check for your app, by default responding on
["health\_check\_paths"](#health_check_paths) with ["serve\_health\_check"](#serve_health_check).

You must provide your own ["health\_check"](#health_check) object that the checks will
be run against.

# NAME

Plack::Middleware::HealthCheck - Health checks for your plack app

# ATTRIBUTES

## health\_check

A [HealthCheck](https://metacpan.org/pod/HealthCheck) object that should have checks with the `ecv_test` tag.

The default object registers `LoadAverage` and `HideFile` checks
with the values from ["load\_limit"](#load_limit) and ["hide\_files"](#hide_files).

## health\_check\_paths

A list of URLs to ["serve\_health\_check"](#serve_health_check) from.

Defaults to `['/healthz']`.

If you don't want any health check paths,
set this to an empty arrayref (`[]`).

## allowed\_params

A list of `query_params` to pass through to `check`.
Parameters are passed with the values in arrayrefs.

Defaults to `undef`,
although `tags` are always passed by ["serve\_health\_check"](#serve_health_check).

# METHODS

## serve\_health\_check

Called with the Plack `$env` hash as an argument
if ["should\_serve\_health\_check"](#should_serve_health_check) returns true.

Returns a `403` forbidden response unless `$env->{REMOTE_ADDR}`
["is\_gsg\_ip" in Shared::Network](https://metacpan.org/pod/Shared::Network#is_gsg_ip).

Reads the query parameters for any `tags` or other ["allowed\_params"](#allowed_params)
and then calls
the ["health\_check"](#health_check) check method with those parameters as well as passing
`$env` under the "env" key.

Returns the result of passing the health check `$result`
to ["health\_check\_response"](#health_check_response).

## should\_serve\_health\_check

Receives the Plack `$env` as an argument and returns a truthy value
if `$env->{PATH_INFO}` matches any of the ["health\_check\_paths"](#health_check_paths).

## health\_check\_response

Takes a health check `$result` and returns a Plack response arrayref.

Returns a 200 response if the `$result->{status}` is "OK",
otherwise returns a 503.

The body of the response is the `$result` JSON encoded.

Also takes an optional [Plack::Request](https://metacpan.org/pod/Plack::Request) object as a second argument
which it will check for the existence of a `pretty` query parameter
in which case it will make the JSON response both `pretty` and `canonical`.

# DEPENDENCIES

[Plack::Middleware](https://metacpan.org/pod/Plack::Middleware),
[HealthCheck](https://metacpan.org/pod/HealthCheck)

# SEE ALSO

The GSG [Health Check Standard](https://support.grantstreet.com/wiki/display/AC/Health+Check+Standard)

# CONFIGURATION AND ENVIRONMENT

None

# AUTHOR

Grant Street Group <developers@grantstreet.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2019 by Grant Street Group.  No
license is granted to other entities.

# CONTRIBUTORS

- Authors:
- (2) Andrew Hewus Fresh <andrew.fresh@grantstreet.com>
