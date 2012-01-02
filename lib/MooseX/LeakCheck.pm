package MooseX::LeakCheck;
use Moose ();
use Moose::Exporter;
use Scalar::Util ();

our $VERSION = '0.002';

{
    package MooseX::LeakCheck::Meta::Attribute;
    use Moose::Role;
    use Moose::Util::TypeConstraints;

    has leak_check => (
        is => 'ro',
    );

    package MooseX::LeakCheck::Meta::Base;
    use Moose::Role;
    use Moose::Util::TypeConstraints;

    sub DEMOLISH {};

    after DEMOLISH => sub {
        my $self = shift;
        my $meta = $self->meta;
        return unless $meta;

        for my $attr ( $meta->get_all_attributes ) {
            next unless my $check = $attr->{leak_check};
            my $name = $attr->name;

            Scalar::Util::weaken $self->{$name};
            next unless $self->{$name};

            if ( ref $check && Scalar::Util::reftype $check eq 'CODE' ) {
                $self->$check( $name, \($self->{$name}) );
            }
            else {
                warn "External ref to attribute '$name' detected on instance '$self'";
            }
        }
    };
}

my ( $import, $unimport, $init_meta ) = Moose::Exporter->build_import_methods(
    also    => ['Moose'],
    install => [qw(import unimport)],
    #

    #attribute_metaclass_roles => ['MooseX::LeakCheck::Meta::Attribute'],
    class_metaroles => {
        attribute  => ['MooseX::LeakCheck::Meta::Attribute'],
    },
    base_class_roles => ['MooseX::LeakCheck::Meta::Base'],
);

sub init_meta {
    my $package = shift;
    my %options = @_;
    Moose->init_meta(%options);
    return $package->$init_meta(%options);
}

1;

__END__

=pod

=head1 NAME

MooseX-LeakCheck - Check for leaky attributes

=head1 DESCRIPTION

Define an attribute that you know should be the only remaining ref to an object
when your instance is destroyed. On destruction verify the attribute is also
destroyed.

=head1 SYNOPSIS

    package Foo;
    use MooseX::LeakCheck;

    has bar => (
        is => 'ro',
        default => sub {[]},
        leak_check => 1,
    );

    has baz => (
        is => 'ro',
        default => sub {[]},
        leak_check => sub {
            my $self = shift;
            my ( $attr_name, $ref ) = @_;
            ...
        }
    );

    has boo => (
        is => 'ro',
        default => sub {[]},
        # Defaults to no
        leak_check => 0,
    );

    1;

=head1 ATTRIBUTE PROPERTIES

=over 4

=item leak_check => $BOOL

=item leak_check => sub { ... }

Turn on leak checking for the attribute when set to true. Generates a warning
when a leak is detected. Alternatively you may provide a coderef callback to
run when a leak is detected.

The coderef gets the following args:
( $self, $attr_name, \$self->{$attr_name})

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2012 Chad Granum

MooseX::LeakCheck is free software; Standard perl licence.

MooseX::LeakCheck is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the license for more details.
=cut
