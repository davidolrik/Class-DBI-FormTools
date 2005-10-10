use Test::More;
use Data::Dumper;

BEGIN {
	eval "use DBD::SQLite";
	plan $@ ? (skip_all => 'needs DBD::SQLite for testing') : (tests => 5);
}

INIT {
    use lib 't/lib';
    use Film;
}

ok(Film->can('db_Main'), 'set_db()');
is(Film->__driver, "SQLite", "Driver set correctly");

my $film1 = Film->create_test_film;

print $film1->form_fieldname('title') ."\n";
print $film1->form_fieldname('length') ."\n";
print $film1->form_fieldname('comment') ."\n";
ok(1);

print $film1->form_field('title','text');
ok(1);

my $film2 = Film->create_test_film;


my $formdata = {
    $film1->form_fieldname('title')    => 'Title',
    $film1->form_fieldname('length')   => 99,
    $film1->form_fieldname('comment')  => 'This is a comment',
    $film2->form_fieldname('title')    => 'Title',
    $film2->form_fieldname('length')   => 99,
    $film2->form_fieldname('comment')  => 'This is a comment',
    Film->form_fieldname('title',   1) => 'Title',
    Film->form_fieldname('length',  1) => 99,
    Film->form_fieldname('comment', 1) => 'This is a comment',
};

my @objects = Class::DBI::FormTools->formdata_to_objects($formdata);
foreach my $object ( @objects ) {
    print 'Extracted object: '.Dumper($object);
    $object->update;
}
ok(1);
