use Test::More;
use Data::Dumper;

BEGIN {
	eval "use DBD::SQLite";
	plan $@ ? (skip_all => 'needs DBD::SQLite for testing') : (tests => 10);
}

INIT {
    use lib 't/lib';
    use Film;
}

ok(Film->can('db_Main'), 'set_db()');
is(Film->__driver, "SQLite", "Driver set correctly");

# Create 2 test objects
my $film1 = Film->create_test_object;
my $film2 = Film->create_test_object;

my $field_definition = qr{
    cdbi    # Prefix
    \|      # Seperator
    [\w:]+  # Classname
    \|      # Seperator
    \d+     # Id field
    \|      # Seperator
    \w*     # Attribute name (optional)
}x;

# Validate that the fields match the definition
like($film1->form_fieldname('title'),   $field_definition,
     "form_fieldname: " . $film1->form_fieldname('title'));
like($film1->form_fieldname('length'),  $field_definition,
     "form_fieldname: " . $film1->form_fieldname('length'));
like($film1->form_fieldname('comment'), $field_definition,
     "form_fieldname: " . $film1->form_fieldname('comment'));

# Validate html creation method
ok($film1->form_field('title','text'),
   "formfield: ".$film1->form_field('title','text'));
ok($film1->form_field('length','text'),
   "formfield: ".$film1->form_field('length','text'));
ok($film1->form_field('comment','text'),
   "formfield: ".$film1->form_field('comment','text'));

#print $film1->form_field('title','checkbox');
#ok('Checkbox field working');

#print $film1->form_field('title','radio');
#ok('Radio field working');


# Create a form with 2 existing objects and 2 new objects
my $formdata = {
    # The existing objects
    $film1->form_fieldname('title')    => 'Title',
    $film1->form_fieldname('length')   => 99,
    $film1->form_fieldname('comment')  => 'This is a comment',
    $film2->form_fieldname('title')    => 'Title',
    $film2->form_fieldname('length')   => 99,
    $film2->form_fieldname('comment')  => 'This is a comment',

    # The new objects
    Film->form_fieldname('title',   1) => 'Title',
    Film->form_fieldname('length',  1) => 99,
    Film->form_fieldname('comment', 1) => 'This is a comment',
    Film->form_fieldname('title',   2) => 'Title',
    Film->form_fieldname('length',  2) => 99,
    Film->form_fieldname('comment', 2) => 'This is a comment',
};
print 'Formdata: '.Dumper($formdata);

# Extract all 4 objects
my @objects = Class::DBI::FormTools->formdata_to_objects($formdata);
ok((grep { ref($_) eq 'Film' } @objects) == 2,
   "formdata_to_objects: Ojects extracted");

print 'Final objects: '.Dumper(\@objects);

# Update objects
foreach my $object ( @objects ) {
    $object->update || diag("Unable to update object $object");
}
ok(1,"Objects updated");


