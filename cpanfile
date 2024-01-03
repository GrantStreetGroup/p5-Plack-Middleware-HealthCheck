requires 'JSON';
requires 'Plack::Middleware';
requires 'Plack::Request';
requires 'Plack::Util::Accessor';
requires 'Hash::MultiValue', '>= 0.1';

on test => sub {
    requires 'HTTP::Request::Common';
    requires 'HealthCheck';
    requires 'Plack::Test';
    requires 'Test::Exception';
};

on develop => sub {
    requires 'Dist::Zilla::PluginBundle::Author::GSG';
};
