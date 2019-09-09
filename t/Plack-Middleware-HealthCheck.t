use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Plack::Middleware::HealthCheck') };

diag(qq(Plack::Middleware::HealthCheck Perl $], $^X));

done_testing;
