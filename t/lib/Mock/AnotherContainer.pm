package Mock::AnotherContainer;
use strict;
use warnings;
use Object::Container::Exporter -base;

register_container_func_name('obj');

register 'foo' => sub {
    my $self = shift;
    $self->load_class('Mock::Foo');
    Mock::Foo->new;
};

1;

