package Class::DBI::FormTools;

use version; $VERSION = qv('0.0.3');

use strict;
use warnings;

use Carp;

use HTML::Element;
use Data::Dumper;

# Other recommended modules (uncomment to use):
#  use IO::Prompt;
#  use Perl6::Export;
#  use Perl6::Slurp;
#  use Perl6::Say;
#  use Regexp::Autoflags;


# Module implementation here


sub form_fieldname
{
    my ($self,$accessor,$object_id,$remote_object_ids) = @_;

    # Get class name
    my $class = ref $self || $self;

    # Set default values
    $remote_object_ids = {} unless $remote_object_ids;

    # Check args based on how we are called
    die join(qq{\n},
             "When calling form_fieldname as a class method on $class,",
             "an object id must be specified"
             ) . "\n"
        if !ref($self) && !defined($object_id);

    my %has_a_attributes;
    foreach my $attr ( keys %{ $class->meta_info->{'has_a'} } ) {
        $has_a_attributes{$attr}
            = $class->meta_info->{'has_a'}->{$attr};
    }

    ## Build primary key field
    my $id_fields = {
        %$remote_object_ids,
    };

    my @id_fields;
    if ( keys %$id_fields ) {
        @id_fields = map { $_.'='.$id_fields->{$_} } keys %$id_fields;
    }
    else {
        push @id_fields, ( ref($self) ) ? $self->id : 'new';
    }

    # Compute fieldname
    my $fieldname = join(
        '|',
        'cdbi',
        $object_id,
        $class,
        join(q{;},@id_fields),
        $accessor || '',
    );
    
    return($fieldname);
}


sub formdata_to_objects
{
    my ($self,$formdata) = @_;

    
    # Mapping from new objects without id's to their new id                                                      
    # A non existing object will have a negative id given to it by the gui                                       
    # e.g. if there are two event objects one will have -1 and the other
    # will have -2 as id. Other objects may reference this negative id, and
    # when the object is created for real (or at least when the id has been
    # selected) the -1 can be replaced with the real value
    # $idmapping->{$object_type}->{$negative_id} = $real_id                                                      
    my $idmapping = {};

    # Extract all cdbi fields
    my @cdbi_formkeys = grep { /^cdbi\|/ } keys %$formdata;

    # Create a todo list with one entry for each unique objects
    # So we can process them in reverse order of dependency
    my %todolist;

    # Sort data into piles for later object creation/updating
    my $processes_data;
    foreach my $formkey ( @cdbi_formkeys ) {
        my ($prefix,$object_id,$class,$id,$attribute) = split(/\|/,$formkey);

        $processes_data->{$class}->{$object_id}->{'raw'}->{$attribute}
            = $formdata->{$formkey};
        $processes_data->{$class}->{$object_id}->{'form_id'}
            = $id;

        # Save class name and id in the todo list
        # (hash used to avoid dupes)
        $todolist{"$class|$object_id"} = {
            class     => $class,
            object_id => $object_id,
        };
    }

    # Flatten todo hash into a todolist array
    my @todolist = values %todolist;
    #warn('TODOLIST: '.Dumper(\@todolist));
    #warn('FORMDATA: '.Dumper($processes_data));

    # Build objects from form data
    my @objects;
    foreach my $todo ( @todolist ) {
        my $object = $self->_inflate_object(
            $todo->{ 'object_id' },
            $todo->{ 'class'     },
            $processes_data,
        );        
        push(@objects,$object);
    }
        
    return(@objects);
}


sub _inflate_object
{
    my ($self,$object_id,$class,$processed_data) = @_;

    ## Get handle on object_id && attributes for the object
    my $attributes = $processed_data->{$class}->{$object_id}->{'raw'};

#warn("===> Inflating $class id: [$object_id] caller: ". (caller())[2] ."\n");
#warn('ATTR: '.Dumper($attributes));

    ## Create id field
    # form_id consists of more than one id field
    my %id_field;
    my $form_id = $processed_data->{$class}->{$object_id}->{'form_id'};
    if ( $form_id && $form_id =~ /;/ ) {
        foreach my $field ( split(/;/,$form_id) ) {
            my ($key,$value) = split(/=/,$field);
            $id_field{$key} = $value;
        }
    }
    # Single column id field
    elsif ( $form_id && $form_id ne 'new' )  {
        %id_field = ( id => $form_id );
    }
    # Fallback to object id (if form_id is missing, it is probably a has_a
    # where the user didn't supply the foreign object as a input parameter)
    elsif ( !$form_id ) {
        %id_field = ( id => $object_id );
    }
    #warn("ID: ".Dumper(\%id_field));

    ## Inflate has_a has_a references
    my @has_a_references = values %{ $class->meta_info->{'has_a'} };
    foreach my $has_a ( @has_a_references ) {
        my $foreign_class    = $has_a->foreign_class;
        my $foreign_accessor = $has_a->accessor->accessor;
        my $foreign_id       = $processed_data
                               ->{$class}
                               ->{$object_id}
                               ->{'raw'}
                               ->{$foreign_accessor}
                             ||= $id_field{$foreign_accessor};
#warn("*** has_a $foreign_accessor [". ($foreign_id ||'')."]");
#warn($foreign_accessor .' '. ($attributes->{$foreign_accessor} || 'undef'));
        next unless $foreign_id;

        # Inflate foreign object
        my $foreign_object = $self->_inflate_object($foreign_id,
                                                    $foreign_class,
                                                    $processed_data,
                                                    );
        # Store inflated object in id and attribute hash
        $attributes->{$foreign_accessor} = $foreign_object;
        $id_field{$foreign_accessor} = $foreign_object
            if exists($id_field{$foreign_accessor});
    }
    #warn('Inflated attrs: '.Dumper($attributes));

    ## Fetch object

    # Is this object allready retrieved?
    my $object = $processed_data->{$class}->{$object_id}->{'object'};

    # No object? - Fetch existing object from database, and store it
    unless  ( $object ) {
        #warn("Fetching $class object");
        $object = $class->retrieve(%id_field) if keys %id_field;
        $processed_data->{$class}->{$object_id}->{'object'} = $object;
    }

    # Still no object?
    unless ( $object ) {
        #warn("Create: ".Dumper(\%id_field));
        
        $object = $class->create({
            %id_field,
            %$attributes,
        });
        $processed_data->{$class}->{$object_id}->{'object'} = $object;
    }

    # Store attributes
    foreach my $attr ( keys %$attributes ) {
        # Skip Dummy columns
        next unless $attr;

        $object->set($attr => $processed_data
                              ->{$class}
                              ->{$object_id}
                              ->{'raw'}
                              ->{$attr});
    }
    #warn("<<< Inflated ".ref($object));
    return($object);
}


sub form_field
{
    my ($self,$name,$type,$object_id,$options,$default) = @_;

    croak "Field '$name' does not exist for object ".ref($self)
        unless $self->can($name);

    my $input;

    if ( $type eq 'text' || $type eq 'hidden' ) {
        $input = $self->_form_field_common(
            $name, $type, $object_id, $options, $default
        );
    }

    my $markup = $input->as_XML;
    chomp($markup);

    return($markup);
}


sub _form_field_common
{
    my ($self,$name,$type,$object_id,$options,$default) = @_;

    my $value = defined($default)   ? $default
              : ref($self)          ? $self->get($name)
              :                     q{}
              ;

    my $input = HTML::Element->new(
        'input',
        name  => $self->form_fieldname($name,$object_id),
        value => $value,
        type  => $type,
    );
    return($input);
}



1; # Magic true value required at end of module
__END__

=head1 NAME

Class::DBI::FormTools - [One line description of module's purpose here]


=head1 VERSION

This document describes Class::DBI::FormTools version 0.0.1


=head1 SYNOPSIS

    use Class::DBI::FormTools;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.

=over

=item form_field

FIXME

=item form_fieldname

FIXME

=item formdata_to_objects

FIXME

=back


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Class::DBI::FormTools requires no configuration files or environment
variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-class-dbi-formtools@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

David Jack Olrik  C<< <david@olrik.dk> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2005, David Jack Olrik C<< <david@olrik.dk> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
