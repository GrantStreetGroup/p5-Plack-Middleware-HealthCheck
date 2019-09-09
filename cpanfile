use GSG::Gitc::CPANfile $_environment;

# Add your requirements here

on develop => sub {
    requires 'Dist::Zilla::PluginBundle::Author::GSG::Internal';
};
