use Test::More;
use Data::Dump 'pp';

BEGIN {
    plan skip_all => 'Nothing to test here';
}

#diag( "Testing Class::DBI::FormTools $Class::DBI::FormTools::VERSION" );

#
my $object;
$object->form_fieldname('name');

$object->form_html_field('name','hidden');
$object->form_html_field('name','text');
$object->form_html_field('name','textarea',{
    cols => '10',
    rows => '30'
});
$object->form_html_field('name','select',{
    style => "border: 1px solid black;"
});
$object->form_html_field('name','radio');
$object->form_html_field('name','checkbox');

$object->form_xml_field('name','hidden');
$object->form_xml_field('name','text');
$object->form_xml_field('name','textarea',{
    cols => '10',
    rows => '30'
});
$object->form_xml_field('name','select',{
    style => "border: 1px solid black;"
});
$object->form_xml_field('name','radio');
$object->form_xml_field('name','checkbox');

#my $html = Class::DBI::FormTools->form_protect('formname','keyphrase',$html);

# In edit page/action
use Class::DBI::FormTools 'xmlmode';

$object->form_field('name','hidden');
$object->form_field('name','text');
$object->form_field('name','textarea',{ cols => '10', rows => '30' });
$object->form_field('name','select',{ style => "border: 1px solid black;" });
$object->form_field('name','radio');
$object->form_field('name','checkbox');



# In save page/action
#my $html;
#Class::DBI::FormTools->form_validate('formname','keyphrase',$html);


my %formdata = (
);
my @objects = Class::DBI::FormTools->formdata_to_objects(%formdata);
foreach my $object ( @objects ) {
    $object->update;
}
TestApp->dbi_commit;