use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Class::DBI::FormTools',
    license             => 'perl',
    dist_author         => 'David Jack Olrik <david@olrik.dk>',
    dist_version_from   => 'lib/Class/DBI/FormTools.pm',
    requires => {
        'Test::More'    => 0,
        'version'       => 0,
        'HTML::Element' => 0,
    },
    add_to_cleanup      => [ 'Class-DBI-FormTools-*' ],
);

$builder->create_build_script();
