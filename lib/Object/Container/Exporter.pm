package Object::Container::Exporter;
use strict;
use warnings;
use parent 'Class::Singleton';
use Class::Load ();

our $VERSION = '0.01';

sub import {
    my ($class, @opts) = @_;

    my $caller = caller;

    if (scalar(@opts) == 1 and ($opts[0]||'') =~ /^-base$/i) {

        {
            no strict 'refs';
            push @{"${caller}::ISA"}, $class;
        }

        for my $func (qw/register register_namespace register_default_container_name/) {
            my $code = $class->can($func);
            no strict 'refs'; ## no critic.
            *{"$caller\::$func"} = sub { $code->($caller, @_) };
        }

        return;
    }
    elsif(scalar(@opts) >= 1 and ($opts[0]||'') !~ /^-no_export/i) {
        $class->_export_functions($caller => @opts);
    }

    unless (($opts[0]||'') =~ /^-no_export$/i) {
        $class->_export_container($caller);
    }
}

sub base_name {
    my $class = shift;
    $class = ref $class unless $class;
    (my $base_name = $class) =~ s/(::.+)?$//g;
    $base_name;
}

sub load_class {
    my ($class, $pkg) = @_;
    Class::Load::load_class($pkg);
}

sub _camelize {
    my $s = shift;
    join('', map{ ucfirst $_ } split(/(?<=[A-Za-z])_(?=[A-Za-z])|\b/, $s));
}

sub _export_functions {
    my ($self, $caller, @export_names) = @_;

    $self = $self->instance unless ref $self;

    for my $name (@export_names) {

        if ($caller->can($name)) { die qq{can't export $name for $caller. $name already defined in $caller.} }

        my $code = $self->{_register_namespace}->{$name} || sub {
            my $target = shift;
            my $container_name = join '::', $self->base_name, _camelize($name), _camelize($target);
            return $target ? $self->get($container_name) : $self;
        };

        {
            no strict 'refs';
            *{"${caller}::${name}"} = $code;
        }
    }
}

sub _export_container {
    my ($class, $caller) = @_;

    my $container_name = $class->instance->{_default_container_name} || 'container';

    if ($caller->can($container_name)) { die qq{can't export '$container_name' for $caller. '$container_name' already defined in $caller.} }
    my $code = sub {
        my $target = shift;
        return $target ? $class->get($target) : $class;
    };
    {
        no strict 'refs';
        *{"${caller}::${container_name}"} = $code;
    }
}

sub register {
    my ($self, $class, @init_opt) = @_;
    $self = $self->instance unless ref $self;

    my $initializer;
    if (@init_opt == 1 and ref($init_opt[0]) eq 'CODE') {
        $initializer = $init_opt[0];
    }
    else {
        $initializer = sub {
            Class::Load::load_class($class);
            $class->new(@init_opt);
        };
    }

    $self->{_registered_classes}->{$class} = $initializer;
}

sub register_namespace {
    my ($self, $method, $pkg) = @_;
    $self = $self->instance unless ref $self;
    my $class = ref $self;

    $pkg = _camelize($pkg);
    my $code = sub {
        my $target = shift;
        my $container_name = join '::', $pkg, _camelize($target);
        Class::Load::load_class($container_name);
        return $target ? $class->get($container_name) : $class;
    };

    $self->{_register_namespace}->{$method} = $code;
}

sub register_default_container_name {
    my ($self, $name) = @_;
    $self = $self->instance unless ref $self;
    $self->{_default_container_name} = $name;
}

sub get {
    my ($self, $class) = @_;
    $self = $self->instance unless ref $self;

    my $obj = $self->{_inflated_classes}->{$class} ||= do {
        my $initializer = $self->{_registered_classes}->{$class};
        $initializer ? $initializer->($self) : ();
    };


    return $obj if $obj;

    Class::Load::load_class($class);
    $obj = $self->{_inflated_classes}->{$class} = $class->new;
    $obj;
}

sub remove {
    my ($self, $class) = @_;
    $self = $self->instance unless ref $self;
    delete $self->{_inflated_classes}->{$class};
}

1;
__END__

=head1 NAME

Object::Container::Exporter -

=head1 SYNOPSIS

  use Object::Container::Exporter;

=head1 DESCRIPTION

Object::Container::Exporter is

=head1 AUTHOR

Atsushi Kobayashi E<lt>nekokak _at_ gmail _dot_ comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
