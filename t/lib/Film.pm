package Film;


use strict;
use warnings;

use lib './t/testlib';
use base 'Class::DBI::Test::SQLite';
use base 'Class::DBI';
use base 'Class::DBI::FormTools';


__PACKAGE__->set_table('film');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(Essential => qw[id title length comment]);

sub create_sql { 
    return q{
        id       INTEGER PRIMARY KEY,
        title    CHAR(40),
        length   INT,
        comment  TEXT
    };
}

sub create_test_film
{
    return shift->create({
        title   => 'Test film',
        length  => 99,
        comment => 'cool!'
    });
}